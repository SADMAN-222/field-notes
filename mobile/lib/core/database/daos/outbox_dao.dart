import 'dart:convert';

import 'package:drift/drift.dart';
import '../database.dart';

class OutboxDao {
  final AppDatabase db;
  OutboxDao(this.db);

  Stream<List<SyncOutboxEntry>> watchAllOutbox(String userId) {
    return (db.select(db.syncOutbox)
          ..where((t) => t.payload.like('%"userId":"$userId"%'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<int> watchPendingCount(String userId) {
    final countExp = db.syncOutbox.id.count();
    final query = db.selectOnly(db.syncOutbox)
      ..where(
        db.syncOutbox.payload.like('%"userId":"$userId"%') &
            db.syncOutbox.state.equals('PENDING'),
      )
      ..addColumns([countExp]);
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  Stream<int> watchFailedCount(String userId) {
    final countExp = db.syncOutbox.id.count();
    final query = db.selectOnly(db.syncOutbox)
      ..where(
        db.syncOutbox.payload.like('%"userId":"$userId"%') &
            db.syncOutbox.state.equals('FAILED'),
      )
      ..addColumns([countExp]);
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  Future<List<SyncOutboxEntry>> getPendingEntries(String userId) {
    return (db.select(db.syncOutbox)
          ..where(
            (t) =>
                t.payload.like('%"userId":"$userId"%') &
                t.state.equals('PENDING'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<void> removeEntries(List<int> ids, String userId) async {
    await (db.delete(db.syncOutbox)..where(
          (t) => t.id.isIn(ids) & t.payload.like('%"userId":"$userId"%'),
        ))
        .go();
  }

  Future<void> markFailed(int id, String userId, String error) async {
    final entry =
        await (db.select(db.syncOutbox)..where(
              (t) => t.id.equals(id) & t.payload.like('%"userId":"$userId"%'),
            ))
            .getSingleOrNull();
    final retry = (entry?.retryCount ?? 0) + 1;
    if (entry == null) return;
    await (db.update(db.syncOutbox)..where(
          (t) => t.id.equals(id) & t.payload.like('%"userId":"$userId"%'),
        ))
        .write(
          SyncOutboxCompanion(
            state: const Value('FAILED'),
            lastError: Value(error),
            retryCount: Value(retry),
          ),
        );
  }

  Future<void> markConflict(
    int id,
    String userId,
    String conflictDetails,
  ) async {
    final entry =
        await (db.select(db.syncOutbox)..where(
              (t) => t.id.equals(id) & t.payload.like('%"userId":"$userId"%'),
            ))
            .getSingleOrNull();
    if (entry == null) return;
    await (db.update(db.syncOutbox)..where(
          (t) => t.id.equals(id) & t.payload.like('%"userId":"$userId"%'),
        ))
        .write(
          SyncOutboxCompanion(
            state: const Value('CONFLICT'),
            lastError: Value(conflictDetails),
            retryCount: Value(entry.retryCount + 1),
          ),
        );
  }

  Future<void> resolveConflictKeepLocal(int entryId, String userId) async {
    final entry =
        await (db.select(db.syncOutbox)..where(
              (t) =>
                  t.id.equals(entryId) & t.payload.like('%"userId":"$userId"%'),
            ))
            .getSingleOrNull();
    if (entry == null || entry.state != 'CONFLICT' || entry.lastError == null) {
      throw StateError(
        'The selected outbox item is not a resolvable conflict.',
      );
    }

    final details = jsonDecode(entry.lastError!);
    if (details is! Map<String, dynamic> || details['conflicts'] is! List) {
      throw StateError('Conflict details are missing or invalid.');
    }
    final conflict = (details['conflicts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (item) =>
              item['entityType'] == entry.entityType &&
              item['entityId'].toString() == entry.entityId,
          orElse: () => throw StateError(
            'The server did not provide a conflict version.',
          ),
        );
    final serverVersion = (conflict['serverVersion'] as num?)?.toInt();
    if (serverVersion == null || serverVersion < 0) {
      throw StateError(
        'This conflict cannot be safely resolved as a local overwrite.',
      );
    }

    final sameEntityEntries =
        await (db.select(db.syncOutbox)
              ..where(
                (t) =>
                    t.entityType.equals(entry.entityType) &
                    t.entityId.equals(entry.entityId) &
                    t.payload.like('%"userId":"$userId"%'),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    final latest = sameEntityEntries.last;
    final payload = jsonDecode(latest.payload!) as Map<String, dynamic>;
    final resolvedVersion = serverVersion + 1;
    payload['version'] = resolvedVersion;

    await db.transaction(() async {
      final duplicateIds = sameEntityEntries
          .where((candidate) => candidate.id != latest.id)
          .map((candidate) => candidate.id)
          .toList();
      if (duplicateIds.isNotEmpty) {
        await removeEntries(duplicateIds, userId);
      }
      await (db.update(
        db.syncOutbox,
      )..where((t) => t.id.equals(latest.id))).write(
        SyncOutboxCompanion(
          operation: const Value('UPDATE'),
          payload: Value(jsonEncode(payload)),
          expectedVersion: Value(resolvedVersion),
          state: const Value('PENDING'),
          lastError: const Value(null),
        ),
      );

      switch (entry.entityType) {
        case 'customer':
          await (db.update(db.customers)..where(
                (t) => t.id.equals(entry.entityId) & t.userId.equals(userId),
              ))
              .write(CustomersCompanion(version: Value(resolvedVersion)));
        case 'site':
          await (db.update(db.sites)..where(
                (t) => t.id.equals(entry.entityId) & t.userId.equals(userId),
              ))
              .write(SitesCompanion(version: Value(resolvedVersion)));
        case 'fieldNote':
          await (db.update(db.fieldNotes)..where(
                (t) => t.id.equals(entry.entityId) & t.userId.equals(userId),
              ))
              .write(FieldNotesCompanion(version: Value(resolvedVersion)));
        default:
          throw StateError('Unsupported conflicting entity type.');
      }
    });
  }

  Future<void> retryAllFailed(String userId) async {
    await (db.update(db.syncOutbox)..where(
          (t) =>
              t.payload.like('%"userId":"$userId"%') & t.state.equals('FAILED'),
        ))
        .write(
          const SyncOutboxCompanion(
            state: Value('PENDING'),
            lastError: Value(null),
          ),
        );
  }

  Future<void> clearForUser(String userId) async {
    await (db.delete(
      db.syncOutbox,
    )..where((t) => t.payload.like('%"userId":"$userId"%'))).go();
  }
}
