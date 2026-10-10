import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../database/tables.dart';
import '../security/secure_storage.dart';

class SyncEngine {
  final AppDatabase db;
  final Dio dio;
  final SecureStorage secureStorage;

  bool _isSyncing = false;

  SyncEngine({required this.db, required this.dio, required this.secureStorage});

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await push();
      await pull();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> push() async {
    final pendingChanges = await (db.select(db.syncOutbox)
          ..where((tbl) => tbl.state.equals('PENDING'))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    if (pendingChanges.isEmpty) return;

    final token = await secureStorage.getAccessToken();
    if (token == null) return; // Auth handled elsewhere

    List<Map<String, dynamic>> operations = pendingChanges.map((entry) {
      return {
        'id': entry.id,
        'entityType': entry.entityType,
        'entityId': entry.entityId,
        'operation': entry.operation,
        'payload': entry.payload != null ? jsonDecode(entry.payload!) : null,
        'expectedVersion': entry.expectedVersion,
      };
    }).toList();

    try {
      final response = await dio.post(
        '/api/v1/sync/push',
        data: {'operations': operations},
        options: Options(headers: {'Authorization': 'Bearer \'}),
      );

      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        for (var result in results) {
          final outboxId = result['id'];
          final success = result['success'];
          
          if (success) {
            await (db.delete(db.syncOutbox)..where((tbl) => tbl.id.equals(outboxId))).go();
          } else {
            await (db.update(db.syncOutbox)..where((tbl) => tbl.id.equals(outboxId))).write(
              SyncOutboxCompanion(state: const Value('FAILED'), lastError: Value(result['error'])),
            );
          }
        }
      }
    } catch (e) {
      print('Sync push error: \');
    }
  }

  Future<void> pull() async {
    final token = await secureStorage.getAccessToken();
    if (token == null) return;

    String cursor = await _getCursor();
    bool hasMore = true;

    while (hasMore) {
      try {
        final response = await dio.get(
          '/api/v1/sync/pull',
          queryParameters: {'cursor': cursor},
          options: Options(headers: {'Authorization': 'Bearer \'}),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          final changes = data['changes'] as List;
          final nextCursor = data['nextCursor'];
          
          await db.transaction(() async {
            for (var change in changes) {
              await _applyChange(change);
            }
            await _saveCursor(nextCursor);
            cursor = nextCursor;
          });

          hasMore = data['hasMore'] ?? false;
        } else {
          hasMore = false;
        }
      } catch (e) {
        print('Sync pull error: \');
        hasMore = false;
      }
    }
  }

  Future<void> _applyChange(Map<String, dynamic> change) async {
    final entityType = change['entityType'];
    final operation = change['operation'];
    final payload = change['payload'];

    if (entityType == 'customer') {
      if (operation == 'DELETE') {
        await (db.update(db.customers)..where((t) => t.id.equals(change['entityId'])))
            .write(CustomersCompanion(deletedAt: Value(DateTime.now())));
      } else {
        await db.into(db.customers).insertOnConflictUpdate(CustomersCompanion.insert(
          id: payload['id'],
          userId: payload['userId'],
          name: payload['name'],
          contactInformation: Value(payload['contactInformation']),
          createdAt: DateTime.parse(payload['createdAt']),
          updatedAt: DateTime.parse(payload['updatedAt']),
          version: Value(payload['version']),
        ));
      }
    } else if (entityType == 'site') {
      if (operation == 'DELETE') {
        await (db.update(db.sites)..where((t) => t.id.equals(change['entityId'])))
            .write(SitesCompanion(deletedAt: Value(DateTime.now())));
      } else {
        await db.into(db.sites).insertOnConflictUpdate(SitesCompanion.insert(
          id: payload['id'],
          userId: payload['userId'],
          customerId: payload['customerId'],
          siteName: payload['siteName'],
          address: Value(payload['address']),
          createdAt: DateTime.parse(payload['createdAt']),
          updatedAt: DateTime.parse(payload['updatedAt']),
          version: Value(payload['version']),
        ));
      }
    } else if (entityType == 'note') {
      if (operation == 'DELETE') {
        await (db.update(db.fieldNotes)..where((t) => t.id.equals(change['entityId'])))
            .write(FieldNotesCompanion(deletedAt: Value(DateTime.now())));
      } else {
        await db.into(db.fieldNotes).insertOnConflictUpdate(FieldNotesCompanion.insert(
          id: payload['id'],
          userId: payload['userId'],
          siteId: payload['siteId'],
          title: payload['title'],
          description: Value(payload['description']),
          status: payload['status'],
          lat: Value(payload['lat']),
          lng: Value(payload['lng']),
          recordedAt: DateTime.parse(payload['recordedAt']),
          photoPath: Value(payload['photoPath']),
          createdAt: DateTime.parse(payload['createdAt']),
          updatedAt: DateTime.parse(payload['updatedAt']),
          version: Value(payload['version']),
        ));
      }
    }
  }

  Future<String> _getCursor() async {
    final entry = await (db.select(db.syncMetadata)..where((t) => t.id.equals('cursor'))).getSingleOrNull();
    return entry?.value ?? '';
  }

  Future<void> _saveCursor(String cursor) async {
    await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(
      id: 'cursor',
      value: Value(cursor),
    ));
  }
}

