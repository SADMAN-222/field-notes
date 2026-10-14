import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'field_notes_dao.g.dart';

@DriftAccessor(tables: [FieldNotes, SyncOutbox])
class FieldNotesDao extends DatabaseAccessor<AppDatabase>
    with _$FieldNotesDaoMixin {
  FieldNotesDao(super.db);

  Stream<List<FieldNote>> watchNotesBySite(String siteId, String userId) {
    return (select(fieldNotes)
          ..where(
            (tbl) =>
                tbl.siteId.equals(siteId) &
                tbl.userId.equals(userId) &
                tbl.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]))
        .watch();
  }

  Stream<List<FieldNote>> watchAllNotes(
    String userId, {
    String? status,
    String? query,
    String? siteId,
  }) {
    final statement = select(fieldNotes).join([
      innerJoin(db.sites, db.sites.id.equalsExp(fieldNotes.siteId)),
      innerJoin(
        db.customers,
        db.customers.id.equalsExp(db.sites.customerId),
      ),
    ]);
    statement.where(
      fieldNotes.userId.equals(userId) &
          fieldNotes.deletedAt.isNull() &
          db.sites.userId.equals(userId) &
          db.sites.deletedAt.isNull() &
          db.customers.userId.equals(userId) &
          db.customers.deletedAt.isNull(),
    );
    if (siteId != null && siteId.isNotEmpty) {
      statement.where(fieldNotes.siteId.equals(siteId));
    }
    if (status != null && status.isNotEmpty && status != 'ALL') {
      statement.where(fieldNotes.status.equals(status));
    }
    if (query != null && query.trim().isNotEmpty) {
      final lowerQuery = '%${query.trim().toLowerCase()}%';
      statement.where(
        fieldNotes.title.lower().like(lowerQuery) |
            fieldNotes.description.lower().like(lowerQuery) |
            db.sites.siteName.lower().like(lowerQuery) |
            db.sites.address.lower().like(lowerQuery) |
            db.customers.name.lower().like(lowerQuery) |
            db.customers.contactInformation.lower().like(lowerQuery),
      );
    }
    statement.orderBy([OrderingTerm.desc(fieldNotes.recordedAt)]);
    return statement.watch().map(
      (rows) => rows.map((row) => row.readTable(fieldNotes)).toList(),
    );
  }

  Stream<List<FieldNote>> watchRecentNotes(String userId, {int limit = 5}) {
    return (select(fieldNotes)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)])
          ..limit(limit))
        .watch();
  }

  Future<FieldNote?> getNoteById(String id, String userId) {
    return (select(
      fieldNotes,
    )..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
        .getSingleOrNull();
  }

  Stream<FieldNote?> watchNoteById(String id, String userId) {
    return (select(
      fieldNotes,
    )..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
        .watchSingleOrNull();
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

  Stream<int> watchNotesCount(String userId, {String? status}) {
    final countExp = fieldNotes.id.count();
    final query = selectOnly(fieldNotes)
      ..where(fieldNotes.userId.equals(userId) & fieldNotes.deletedAt.isNull());
    if (status != null && status.isNotEmpty && status != 'ALL') {
      query.where(fieldNotes.status.equals(status));
    }
    query.addColumns([countExp]);
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
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

      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          entityType: 'note',
          entityId: note.id,
          operation: 'CREATE',
          payload: Value(payload),
          expectedVersion: Value(0),
          createdAt: DateTime.now(),
        ),
      );
      await _enqueuePhotoUpload(note);
    });
  }

  Future<void> updateNote(FieldNote note) {
    return transaction(() async {
      final updated = await (update(fieldNotes)
            ..where(
              (tbl) =>
                  tbl.id.equals(note.id) & tbl.userId.equals(note.userId),
            ))
          .write(note.toCompanion(true));
      if (updated != 1) {
        throw StateError('Field note does not belong to the active account.');
      }
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

      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          entityType: 'note',
          entityId: note.id,
          operation: 'UPDATE',
          payload: Value(payload),
          expectedVersion: Value(note.version),
          createdAt: DateTime.now(),
        ),
      );
      await _enqueuePhotoUpload(note);
    });
  }

  Future<void> deleteNote(FieldNote note) {
    return transaction(() async {
      final deletedNote = note.copyWith(deletedAt: Value(DateTime.now()));
      final updated = await (update(fieldNotes)
            ..where(
              (tbl) =>
                  tbl.id.equals(note.id) & tbl.userId.equals(note.userId),
            ))
          .write(FieldNotesCompanion(deletedAt: Value(deletedNote.deletedAt)));
      if (updated != 1) {
        throw StateError('Field note does not belong to the active account.');
      }

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

      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          entityType: 'note',
          entityId: note.id,
          operation: 'DELETE',
          payload: Value(payload),
          expectedVersion: Value(note.version),
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  Future<void> upsertFromServer(FieldNote note) async {
    await into(fieldNotes).insertOnConflictUpdate(note);
  }

  Future<void> deleteFromServer(String noteId, String userId) async {
    await (update(fieldNotes)
          ..where((t) => t.id.equals(noteId) & t.userId.equals(userId)))
        .write(
      FieldNotesCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> _enqueuePhotoUpload(FieldNote note) async {
    final photoPath = note.photoPath;
    if (photoPath == null || photoPath.isEmpty) return;

    await into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        entityType: 'photo',
        entityId: note.id,
        operation: 'UPLOAD',
        payload: Value(
          jsonEncode({
            'userId': note.userId,
            'noteId': note.id,
            'photoPath': photoPath,
          }),
        ),
        createdAt: DateTime.now(),
      ),
    );
  }
}
