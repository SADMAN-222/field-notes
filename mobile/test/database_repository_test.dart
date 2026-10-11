import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:field_notes_test/core/database/database.dart';
import 'package:field_notes_test/core/database/daos/customer_dao.dart';
import 'package:field_notes_test/core/database/daos/sites_dao.dart';
import 'package:field_notes_test/core/database/daos/field_notes_dao.dart';
import 'package:field_notes_test/core/database/daos/outbox_dao.dart';
import 'package:field_notes_test/features/customers/customer_repository.dart';
import 'package:field_notes_test/features/sites/site_repository.dart';
import 'package:field_notes_test/features/field_notes/field_note_repository.dart';
import 'test_helper.dart';

void main() {
  setUpAll(() {
    setupSqliteForTest();
  });

  late AppDatabase db;
  late CustomerDao customerDao;
  late CustomerRepository customerRepo;
  late SitesDao sitesDao;
  late SiteRepository siteRepo;
  late FieldNotesDao fieldNotesDao;
  late FieldNoteRepository fieldNoteRepo;
  late OutboxDao outboxDao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    customerDao = CustomerDao(db);
    customerRepo = CustomerRepository(customerDao: customerDao);
    sitesDao = SitesDao(db);
    siteRepo = SiteRepository(sitesDao: sitesDao);
    fieldNotesDao = FieldNotesDao(db);
    fieldNoteRepo = FieldNoteRepository(fieldNotesDao: fieldNotesDao);
    outboxDao = OutboxDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CustomerDao & CustomerRepository Offline CRUD & Outbox Queue', () {
    const userId = 'user-abc';
    final now = DateTime.now();

    test('addCustomer persists customer and enqueues CREATE outbox entry', () async {
      final customer = Customer(
        id: 'cust-1',
        userId: userId,
        name: 'Acme Corporation',
        contactInformation: 'contact@acme.com | 555-0100',
        createdAt: now,
        updatedAt: now,
        version: 0,
      );

      await customerRepo.addCustomer(customer);

      final fetched = await customerRepo.getCustomerById('cust-1');
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Acme Corporation'));
      expect(fetched.contactInformation, equals('contact@acme.com | 555-0100'));

      final allCustomers = await customerRepo.getAllCustomers(userId);
      expect(allCustomers.length, equals(1));
      expect(allCustomers.first.id, equals('cust-1'));

      final count = await customerRepo.getCustomerCount(userId);
      expect(count, equals(1));

      // Check Outbox
      final outboxEntries = await outboxDao.getPendingEntries();
      expect(outboxEntries.length, equals(1));
      final entry = outboxEntries.first;
      expect(entry.entityType, equals('customer'));
      expect(entry.entityId, equals('cust-1'));
      expect(entry.operation, equals('CREATE'));
      expect(entry.state, equals('PENDING'));

      final payload = jsonDecode(entry.payload!) as Map<String, dynamic>;
      expect(payload['id'], equals('cust-1'));
      expect(payload['name'], equals('Acme Corporation'));
    });

    test('updateCustomer updates database record and enqueues UPDATE outbox entry', () async {
      final customer = Customer(
        id: 'cust-2',
        userId: userId,
        name: 'Beta Global',
        contactInformation: 'info@beta.com',
        createdAt: now,
        updatedAt: now,
        version: 0,
      );
      await customerRepo.addCustomer(customer);

      final updated = customer.copyWith(
        name: 'Beta Global Industries',
        contactInformation: const Value('new-info@beta.com'),
        version: 1,
        updatedAt: DateTime.now(),
      );
      await customerRepo.updateCustomer(updated);

      final fetched = await customerRepo.getCustomerById('cust-2');
      expect(fetched!.name, equals('Beta Global Industries'));
      expect(fetched.contactInformation, equals('new-info@beta.com'));

      final outboxEntries = await outboxDao.getPendingEntries();
      expect(outboxEntries.length, equals(2));
      expect(outboxEntries[1].operation, equals('UPDATE'));
      expect(outboxEntries[1].expectedVersion, equals(1));
    });

    test('deleteCustomer sets deletedAt and enqueues DELETE outbox entry', () async {
      final customer = Customer(
        id: 'cust-3',
        userId: userId,
        name: 'Gamma Tech',
        contactInformation: 'support@gamma.com',
        createdAt: now,
        updatedAt: now,
        version: 0,
      );
      await customerRepo.addCustomer(customer);

      await customerRepo.deleteCustomer(customer);

      // Active customer list should now be empty
      final allCustomers = await customerRepo.getAllCustomers(userId);
      expect(allCustomers, isEmpty);

      final count = await customerRepo.getCustomerCount(userId);
      expect(count, equals(0));

      // But row still exists in DB with deletedAt timestamp
      final directRow = await customerRepo.getCustomerById('cust-3');
      expect(directRow, isNotNull);
      expect(directRow!.deletedAt, isNotNull);

      final outboxEntries = await outboxDao.getPendingEntries();
      expect(outboxEntries.length, equals(2));
      expect(outboxEntries[1].operation, equals('DELETE'));
    });

    test('searchCustomers filters by name or contact', () async {
      await customerRepo.addCustomer(Customer(
        id: 'c1',
        userId: userId,
        name: 'Solar Energy Labs',
        contactInformation: 'hello@solarlabs.com',
        createdAt: now,
        updatedAt: now,
        version: 0,
      ));
      await customerRepo.addCustomer(Customer(
        id: 'c2',
        userId: userId,
        name: 'Wind Turbines Inc',
        contactInformation: 'service@wind.org',
        createdAt: now,
        updatedAt: now,
        version: 0,
      ));

      final searchSolar = await customerRepo.searchCustomers(userId, 'solar').first;
      expect(searchSolar.length, equals(1));
      expect(searchSolar.first.id, equals('c1'));

      final searchOrg = await customerRepo.searchCustomers(userId, 'wind.org').first;
      expect(searchOrg.length, equals(1));
      expect(searchOrg.first.id, equals('c2'));

      final searchNone = await customerRepo.searchCustomers(userId, 'nuclear').first;
      expect(searchNone, isEmpty);
    });
  });

  group('SitesDao & SiteRepository Offline CRUD & Outbox Queue', () {
    const userId = 'user-abc';
    const customerId = 'cust-100';
    final now = DateTime.now();

    test('addSite persists site and creates CREATE outbox item', () async {
      final site = Site(
        id: 'site-1',
        userId: userId,
        customerId: customerId,
        siteName: 'Downtown Substation',
        address: '100 Main St, Metropolis',
        createdAt: now,
        updatedAt: now,
        version: 0,
      );

      await siteRepo.addSite(site);

      final fetched = await siteRepo.getSiteById('site-1');
      expect(fetched, isNotNull);
      expect(fetched!.siteName, equals('Downtown Substation'));
      expect(fetched.address, equals('100 Main St, Metropolis'));

      final customerSites = await siteRepo.watchSites(customerId).first;
      expect(customerSites.length, equals(1));
      expect(customerSites.first.id, equals('site-1'));

      final allSites = await siteRepo.getAllSites(userId);
      expect(allSites.length, equals(1));

      final outbox = await outboxDao.getPendingEntries();
      expect(outbox.length, equals(1));
      expect(outbox.first.entityType, equals('site'));
      expect(outbox.first.entityId, equals('site-1'));
      expect(outbox.first.operation, equals('CREATE'));
    });

    test('updateSite modifies site and records UPDATE outbox item', () async {
      final site = Site(
        id: 'site-2',
        userId: userId,
        customerId: customerId,
        siteName: 'North Gate Facility',
        address: '500 North Ave',
        createdAt: now,
        updatedAt: now,
        version: 0,
      );
      await siteRepo.addSite(site);

      final updated = site.copyWith(
        siteName: 'North Gate Plant 2',
        version: 1,
        updatedAt: DateTime.now(),
      );
      await siteRepo.updateSite(updated);

      final fetched = await siteRepo.getSiteById('site-2');
      expect(fetched!.siteName, equals('North Gate Plant 2'));

      final outbox = await outboxDao.getPendingEntries();
      expect(outbox.length, equals(2));
      expect(outbox[1].operation, equals('UPDATE'));
    });

    test('deleteSite soft-deletes and enqueues DELETE outbox item', () async {
      final site = Site(
        id: 'site-3',
        userId: userId,
        customerId: customerId,
        siteName: 'Old Facility',
        address: '300 Abandoned Rd',
        createdAt: now,
        updatedAt: now,
        version: 0,
      );
      await siteRepo.addSite(site);

      await siteRepo.deleteSite(site);

      final active = await siteRepo.getAllSites(userId);
      expect(active, isEmpty);

      final outbox = await outboxDao.getPendingEntries();
      expect(outbox.length, equals(2));
      expect(outbox[1].operation, equals('DELETE'));
    });

    test('searchSites finds matches by name or address', () async {
      await siteRepo.addSite(Site(
        id: 's1',
        userId: userId,
        customerId: customerId,
        siteName: 'Alpha Building',
        address: '77 Broad St',
        createdAt: now,
        updatedAt: now,
        version: 0,
      ));
      await siteRepo.addSite(Site(
        id: 's2',
        userId: userId,
        customerId: customerId,
        siteName: 'Beta Tower',
        address: '100 Broadway',
        createdAt: now,
        updatedAt: now,
        version: 0,
      ));

      final matchAlpha = await siteRepo.searchSites(userId, 'alpha').first;
      expect(matchAlpha.length, equals(1));
      expect(matchAlpha.first.id, equals('s1'));

      final matchBroad = await siteRepo.searchSites(userId, 'broad').first;
      expect(matchBroad.length, equals(2));
    });
  });

  group('FieldNotesDao & FieldNoteRepository Offline CRUD & Outbox Queue', () {
    const userId = 'user-abc';
    const siteId = 'site-100';
    final now = DateTime.now();

    test('addNote saves note and creates CREATE outbox item', () async {
      final note = FieldNote(
        id: 'note-1',
        userId: userId,
        siteId: siteId,
        title: 'Generator Inspection Check',
        description: 'No fuel leaks found. Battery voltage healthy at 13.8V.',
        status: 'SUBMITTED',
        lat: 37.7749,
        lng: -122.4194,
        photoPath: '/local/cache/photo_1.jpg',
        recordedAt: now,
        createdAt: now,
        updatedAt: now,
        version: 0,
      );

      await fieldNoteRepo.addNote(note);

      final fetched = await fieldNoteRepo.getNoteById('note-1');
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Generator Inspection Check'));
      expect(fetched.status, equals('SUBMITTED'));
      expect(fetched.lat, equals(37.7749));
      expect(fetched.lng, equals(-122.4194));

      final siteNotes = await fieldNoteRepo.watchNotes(siteId).first;
      expect(siteNotes.length, equals(1));

      final countSubmitted = await fieldNoteRepo.getNotesCount(userId, status: 'SUBMITTED');
      expect(countSubmitted, equals(1));

      final countDraft = await fieldNoteRepo.getNotesCount(userId, status: 'DRAFT');
      expect(countDraft, equals(0));

      final outbox = await outboxDao.getPendingEntries();
      expect(outbox.length, equals(1));
      expect(outbox.first.entityType, equals('note'));
      expect(outbox.first.entityId, equals('note-1'));
      expect(outbox.first.operation, equals('CREATE'));
    });

    test('updateNote updates field note and adds UPDATE outbox item', () async {
      final note = FieldNote(
        id: 'note-2',
        userId: userId,
        siteId: siteId,
        title: 'Initial Draft Inspection',
        description: 'Pending battery check.',
        status: 'DRAFT',
        recordedAt: now,
        createdAt: now,
        updatedAt: now,
        version: 0,
      );
      await fieldNoteRepo.addNote(note);

      final updated = note.copyWith(
        title: 'Finalized Generator Inspection',
        status: 'SYNCED',
        version: 1,
        updatedAt: DateTime.now(),
      );
      await fieldNoteRepo.updateNote(updated);

      final fetched = await fieldNoteRepo.getNoteById('note-2');
      expect(fetched!.title, equals('Finalized Generator Inspection'));
      expect(fetched.status, equals('SYNCED'));

      final outbox = await outboxDao.getPendingEntries();
      expect(outbox.length, equals(2));
      expect(outbox[1].operation, equals('UPDATE'));
    });

    test('deleteNote soft-deletes and adds DELETE outbox item', () async {
      final note = FieldNote(
        id: 'note-3',
        userId: userId,
        siteId: siteId,
        title: 'Obsolete Note',
        description: 'To be discarded',
        status: 'DRAFT',
        recordedAt: now,
        createdAt: now,
        updatedAt: now,
        version: 0,
      );
      await fieldNoteRepo.addNote(note);

      await fieldNoteRepo.deleteNote(note);

      final active = await fieldNoteRepo.watchNotes(siteId).first;
      expect(active, isEmpty);

      final outbox = await outboxDao.getPendingEntries();
      expect(outbox.length, equals(2));
      expect(outbox[1].operation, equals('DELETE'));
    });

    test('watchAllNotes supports filtering by status and query', () async {
      await fieldNoteRepo.addNote(FieldNote(
        id: 'n1',
        userId: userId,
        siteId: siteId,
        title: 'Transformer Maintenance',
        description: 'Replaced coolant filter',
        status: 'SYNCED',
        recordedAt: now,
        createdAt: now,
        updatedAt: now,
        version: 0,
      ));
      await fieldNoteRepo.addNote(FieldNote(
        id: 'n2',
        userId: userId,
        siteId: siteId,
        title: 'HVAC Duct Clean',
        description: 'Filter clean complete',
        status: 'DRAFT',
        recordedAt: now,
        createdAt: now,
        updatedAt: now,
        version: 0,
      ));

      // Filter by status
      final syncedNotes = await fieldNoteRepo.watchAllNotes(userId, status: 'SYNCED').first;
      expect(syncedNotes.length, equals(1));
      expect(syncedNotes.first.id, equals('n1'));

      final draftNotes = await fieldNoteRepo.watchAllNotes(userId, status: 'DRAFT').first;
      expect(draftNotes.length, equals(1));
      expect(draftNotes.first.id, equals('n2'));

      // Filter by search query
      final filterNotes = await fieldNoteRepo.watchAllNotes(userId, query: 'coolant').first;
      expect(filterNotes.length, equals(1));
      expect(filterNotes.first.id, equals('n1'));
    });
  });

  group('OutboxDao State Transitions', () {
    test('markFailed, retryAllFailed, and removeEntries behavior', () async {
      // Add a dummy entry
      await customerRepo.addCustomer(Customer(
        id: 'cust-x',
        userId: 'user-x',
        name: 'Test Co',
        contactInformation: 'test@co.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 0,
      ));

      final pendingBefore = await outboxDao.getPendingEntries();
      expect(pendingBefore.length, equals(1));
      final entryId = pendingBefore.first.id;

      // Mark as failed
      await outboxDao.markFailed(entryId, '500 Server Internal Error');

      // Now pending should be empty because it is FAILED
      final pendingAfterFail = await outboxDao.getPendingEntries();
      expect(pendingAfterFail, isEmpty);

      // Verify failed state and retry count
      final allOutbox = await outboxDao.watchAllOutbox().first;
      expect(allOutbox.first.state, equals('FAILED'));
      expect(allOutbox.first.retryCount, equals(1));
      expect(allOutbox.first.lastError, equals('500 Server Internal Error'));

      // Retry all failed
      await outboxDao.retryAllFailed();
      final pendingAfterRetry = await outboxDao.getPendingEntries();
      expect(pendingAfterRetry.length, equals(1));
      expect(pendingAfterRetry.first.state, equals('PENDING'));
      expect(pendingAfterRetry.first.lastError, isNull);

      // Remove entry
      await outboxDao.removeEntries([entryId]);
      final pendingAfterRemove = await outboxDao.getPendingEntries();
      expect(pendingAfterRemove, isEmpty);
    });
  });
}
