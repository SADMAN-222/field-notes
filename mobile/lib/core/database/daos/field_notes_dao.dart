import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';
import 'dart:convert';

part 'field_notes_dao.g.dart';

@DriftAccessor(tables: [FieldNotes, SyncOutbox])
class FieldNotesDao extends DatabaseAccessor<AppDatabase> with _$FieldNotesDaoMixin {
  FieldNotesDao(AppDatabase db) : super(db);

  Stream<List<FieldNote>> watchNotesBySite(String siteId) {
    return (select(fieldNotes)..where((tbl) => tbl.siteId.equals(siteId) & tbl.deletedAt.isNull())).watch();
  }

  Stream<List<FieldNote>> watchAllNotes(String userId) {
    return (select(fieldNotes)..where((tbl) => tbl.userId.equals(userId) & tbl.deletedAt.isNull())).watch();
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

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'note',
        entityId: note.id,
        operation: 'DELETE',
        expectedVersion: Value(note.version),
        createdAt: DateTime.now(),
      ));
    });
  }
}

