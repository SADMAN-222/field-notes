import 'package:drift/drift.dart';
import '../database.dart';

class OutboxDao {
  final AppDatabase db;
  OutboxDao(this.db);

  Stream<List<SyncOutboxEntry>> watchAllOutbox() {
    return (db.select(db.syncOutbox)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Stream<int> watchPendingCount() {
    final countExp = db.syncOutbox.id.count();
    final query = db.selectOnly(db.syncOutbox)
      ..where(db.syncOutbox.state.equals('PENDING'))
      ..addColumns([countExp]);
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  Stream<int> watchFailedCount() {
    final countExp = db.syncOutbox.id.count();
    final query = db.selectOnly(db.syncOutbox)
      ..where(db.syncOutbox.state.equals('FAILED'))
      ..addColumns([countExp]);
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  Future<List<SyncOutboxEntry>> getPendingEntries() {
    return (db.select(db.syncOutbox)
          ..where((t) => t.state.equals('PENDING'))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<void> removeEntries(List<int> ids) async {
    await (db.delete(db.syncOutbox)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> markFailed(int id, String error) async {
    final entry = await (db.select(db.syncOutbox)..where((t) => t.id.equals(id))).getSingleOrNull();
    final retry = (entry?.retryCount ?? 0) + 1;
    await (db.update(db.syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        state: const Value('FAILED'),
        lastError: Value(error),
        retryCount: Value(retry),
      ),
    );
  }

  Future<void> retryAllFailed() async {
    await (db.update(db.syncOutbox)..where((t) => t.state.equals('FAILED'))).write(
      const SyncOutboxCompanion(
        state: Value('PENDING'),
        lastError: Value(null),
      ),
    );
  }

  Future<void> clearAll() async {
    await db.delete(db.syncOutbox).go();
  }
}
