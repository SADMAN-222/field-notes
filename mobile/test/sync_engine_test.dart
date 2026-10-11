import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:field_notes_test/core/database/database.dart';
import 'package:field_notes_test/core/database/daos/outbox_dao.dart';
import 'package:field_notes_test/core/database/daos/customer_dao.dart';
import 'package:field_notes_test/core/security/secure_storage.dart';
import 'package:field_notes_test/core/storage/preferences_service.dart';
import 'package:field_notes_test/core/sync/sync_engine.dart';
import 'test_helper.dart';

class MockDio extends Mock implements Dio {}
class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupSqliteForTest();
  });

  late AppDatabase db;
  late OutboxDao outboxDao;
  late CustomerDao customerDao;
  late MockDio mockDio;
  late MockSecureStorage mockSecureStorage;
  late PreferencesService preferencesService;
  late SyncEngine syncEngine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outboxDao = OutboxDao(db);
    customerDao = CustomerDao(db);
    mockDio = MockDio();
    mockSecureStorage = MockSecureStorage();

    SharedPreferences.setMockInitialValues({
      'pref_auto_sync': true,
      'pref_sync_interval': 30,
    });
    final prefs = await SharedPreferences.getInstance();
    preferencesService = PreferencesService(prefs);

    syncEngine = SyncEngine(
      db: db,
      dio: mockDio,
      secureStorage: mockSecureStorage,
      preferencesService: preferencesService,
      outboxDao: outboxDao,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
  });

  group('SyncEngine', () {
    test('sync skips gracefully when user has no access token', () async {
      when(() => mockSecureStorage.getAccessToken()).thenAnswer((_) async => null);

      await syncEngine.sync();

      verifyNever(() => mockDio.post(any(), data: any(named: 'data')));
      verifyNever(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')));
      expect(syncEngine.isSyncing, isFalse);
    });

    test('push gathers outbox entries, sends to /api/v1/sync/push, and cleans up outbox on 200', () async {
      when(() => mockSecureStorage.getAccessToken()).thenAnswer((_) async => 'valid-jwt');

      // Add a customer via DAO which writes to outbox
      final now = DateTime.now();
      await customerDao.createCustomer(Customer(
        id: 'cust-sync-1',
        userId: 'user-123',
        name: 'Sync Test Customer',
        contactInformation: 'test@sync.com',
        createdAt: now,
        updatedAt: now,
        version: 0,
      ));

      final pendingBefore = await outboxDao.getPendingEntries();
      expect(pendingBefore.length, equals(1));

      // Mock Dio push response
      when(() => mockDio.post(
            '/api/v1/sync/push',
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/sync/push'),
            statusCode: 200,
            data: {'status': 'SUCCESS'},
          ));

      await syncEngine.push();

      // Pending outbox entries should have been safely deleted
      final pendingAfter = await outboxDao.getPendingEntries();
      expect(pendingAfter, isEmpty);
    });

    test('push marks entries as FAILED if server returns 500 error', () async {
      when(() => mockSecureStorage.getAccessToken()).thenAnswer((_) async => 'valid-jwt');

      final now = DateTime.now();
      await customerDao.createCustomer(Customer(
        id: 'cust-sync-err',
        userId: 'user-123',
        name: 'Failing Sync Customer',
        contactInformation: 'err@sync.com',
        createdAt: now,
        updatedAt: now,
        version: 0,
      ));

      when(() => mockDio.post(
            '/api/v1/sync/push',
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/v1/sync/push'),
        error: 'Connection refused',
      ));

      try {
        await syncEngine.push();
      } catch (_) {}

      final pendingAfter = await outboxDao.getPendingEntries();
      expect(pendingAfter, isEmpty); // No longer PENDING

      final allOutbox = await outboxDao.watchAllOutbox().first;
      expect(allOutbox.first.state, equals('FAILED'));
    });

    test('pull fetches server items and writes to local SQLite database', () async {
      when(() => mockSecureStorage.getAccessToken()).thenAnswer((_) async => 'valid-jwt');
      when(() => mockSecureStorage.getUserId()).thenAnswer((_) async => 'user-123');

      final serverCustomers = [
        {
          'id': 'remote-cust-1',
          'name': 'Remote Customer Inc',
          'contactInformation': 'remote@corp.com',
          'createdAt': '2026-03-01T12:00:00Z',
          'updatedAt': '2026-03-01T12:00:00Z',
          'deletedAt': null,
          'version': 1,
        }
      ];

      final serverSites = [
        {
          'id': 'remote-site-1',
          'customerId': 'remote-cust-1',
          'siteName': 'Remote Solar Park',
          'address': 'Highway 101',
          'createdAt': '2026-03-01T12:00:00Z',
          'updatedAt': '2026-03-01T12:00:00Z',
          'deletedAt': null,
          'version': 1,
        }
      ];

      final serverNotes = [
        {
          'id': 'remote-note-1',
          'siteId': 'remote-site-1',
          'title': 'Remote Inverter Check',
          'description': 'Working normally',
          'status': 'SYNCED',
          'lat': 34.05,
          'lng': -118.25,
          'photoPath': null,
          'recordedAt': '2026-03-01T12:00:00Z',
          'createdAt': '2026-03-01T12:00:00Z',
          'updatedAt': '2026-03-01T12:00:00Z',
          'deletedAt': null,
          'version': 1,
        }
      ];

      when(() => mockDio.get(
            '/api/v1/sync/pull',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/sync/pull'),
            statusCode: 200,
            data: {
              'customers': serverCustomers,
              'sites': serverSites,
              'fieldNotes': serverNotes,
              'newCursor': '2026-03-01T12:00:00Z',
            },
          ));

      await syncEngine.pull();

      // Verify records are inserted into SQLite
      final pulledCustomer = await customerDao.getCustomerById('remote-cust-1');
      expect(pulledCustomer, isNotNull);
      expect(pulledCustomer!.name, equals('Remote Customer Inc'));

      final pulledSite = await (db.select(db.sites)..where((t) => t.id.equals('remote-site-1'))).getSingleOrNull();
      expect(pulledSite, isNotNull);
      expect(pulledSite!.siteName, equals('Remote Solar Park'));

      final pulledNote = await (db.select(db.fieldNotes)..where((t) => t.id.equals('remote-note-1'))).getSingleOrNull();
      expect(pulledNote, isNotNull);
      expect(pulledNote!.title, equals('Remote Inverter Check'));
    });
  });
}
