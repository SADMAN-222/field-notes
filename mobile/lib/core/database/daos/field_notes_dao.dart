import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'field_notes_dao.g.dart';

@DriftAccessor(tables: [FieldNotes, SyncOutbox])
class FieldNotesDao extends DatabaseAccessor<AppDatabase> with _$FieldNotesDaoMixin {
  FieldNotesDao(super.db);

  Stream<List<FieldNote>> watchNotesBySite(String siteId) {
    return (select(fieldNotes)
          ..where((tbl) => tbl.siteId.equals(siteId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]))
        .watch();
  }

  Stream<List<FieldNote>> watchAllNotes(
    String userId, {
    String? status,
    String? query,
    String? siteId,
  }) {
    return (select(fieldNotes)
          ..where((tbl) {
            var expr = tbl.userId.equals(userId) & tbl.deletedAt.isNull();
            if (siteId != null && siteId.isNotEmpty) {
              expr = expr & tbl.siteId.equals(siteId);
            }
            if (status != null && status.isNotEmpty && status != 'ALL') {
              expr = expr & tbl.status.equals(status);
            }
            if (query != null && query.trim().isNotEmpty) {
              final lowerQuery = '%${query.toLowerCase()}%';
              expr = expr &
                  (tbl.title.lower().like(lowerQuery) |
                      tbl.description.lower().like(lowerQuery));
            }
            return expr;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]))
        .watch();
  }

  Stream<List<FieldNote>> watchRecentNotes(String userId, {int limit = 5}) {
    return (select(fieldNotes)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)])
          ..limit(limit))
        .watch();
  }

  Future<FieldNote?> getNoteById(String id) {
    return (select(fieldNotes)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Stream<FieldNote?> watchNoteById(String id) {
    return (select(fieldNotes)..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
  }

  Future<int> getNotesCount(String userId, {String? status}) async {
    final countExp = fieldNotes.id.count();
    final query = selectOnly(fieldNotes)
      ..where(fieldNotes.userId.equals(userId) & fieldNotes.deletedAt.isNull());
    if (status != null && status.isNotEmpty && status != 'ALL') {
      query.where(fieldNotes.status.equals(status));
    }
    query.addColumns([countExp]);
    return await query.map((row) => row.read(countExp)).getSingle() ?? 0;
  }

  Future<void> createNote(FieldNote note) {
    return transaction(() async {
      await into(fieldNotes).insert(note);
      final payload = jsonEncode({
        'id': note.id,
        'userId': note.userId,
        'siteId': note.siteId,
        'title': note.title,
        'description': note.description,
        'status': note.status,
        'lat': note.lat,
        'lng': note.lng,
        'recordedAt': note.recordedAt.toIso8601String(),
        'photoPath': note.photoPath,
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
        'deletedAt': note.deletedAt?.toIso8601String(),
        'version': note.version,
      });

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'note',
        entityId: note.id,
        operation: 'CREATE',
        payload: Value(payload),
        expectedVersion: Value(0),
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> updateNote(FieldNote note) {
    return transaction(() async {
      await update(fieldNotes).replace(note);
      final payload = jsonEncode({
        'id': note.id,
        'userId': note.userId,
        'siteId': note.siteId,
        'title': note.title,
        'description': note.description,
        'status': note.status,
        'lat': note.lat,
        'lng': note.lng,
        'recordedAt': note.recordedAt.toIso8601String(),
        'photoPath': note.photoPath,
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
        'deletedAt': note.deletedAt?.toIso8601String(),
        'version': note.version,
      });

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'note',
        entityId: note.id,
        operation: 'UPDATE',
        payload: Value(payload),
        expectedVersion: Value(note.version),
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> deleteNote(FieldNote note) {
    return transaction(() async {
      final deletedNote = note.copyWith(deletedAt: Value(DateTime.now()));
      await update(fieldNotes).replace(deletedNote);

      final payload = jsonEncode({
        'id': note.id,
        'userId': note.userId,
        'siteId': note.siteId,
        'title': note.title,
        'description': note.description,
        'status': note.status,
        'lat': note.lat,
        'lng': note.lng,
        'recordedAt': note.recordedAt.toIso8601String(),
        'photoPath': note.photoPath,
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
        'deletedAt': deletedNote.deletedAt?.toIso8601String(),
        'version': note.version,
      });

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'note',
        entityId: note.id,
        operation: 'DELETE',
        payload: Value(payload),
        expectedVersion: Value(note.version),
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> upsertFromServer(FieldNote note) async {
    await into(fieldNotes).insertOnConflictUpdate(note);
  }

  Future<void> deleteFromServer(String noteId) async {
    await (update(fieldNotes)..where((t) => t.id.equals(noteId)))
        .write(FieldNotesCompanion(deletedAt: Value(DateTime.now())));
  }
}
