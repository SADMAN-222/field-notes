import '../../core/database/database.dart';
import '../../core/database/daos/field_notes_dao.dart';

class FieldNoteRepository {
  final FieldNotesDao fieldNotesDao;

  FieldNoteRepository({required this.fieldNotesDao});

  Stream<List<FieldNote>> watchNotes(String siteId) =>
      fieldNotesDao.watchNotesBySite(siteId);

  Stream<List<FieldNote>> watchAllNotes(
    String userId, {
    String? status,
    String? query,
    String? siteId,
  }) =>
      fieldNotesDao.watchAllNotes(
        userId,
        status: status,
        query: query,
        siteId: siteId,
      );

  Stream<List<FieldNote>> watchRecentNotes(String userId, {int limit = 5}) =>
      fieldNotesDao.watchRecentNotes(userId, limit: limit);

  Future<FieldNote?> getNoteById(String id) =>
      fieldNotesDao.getNoteById(id);

  Stream<FieldNote?> watchNoteById(String id) =>
      fieldNotesDao.watchNoteById(id);

  Future<int> getNotesCount(String userId, {String? status}) =>
      fieldNotesDao.getNotesCount(userId, status: status);

  Future<void> addNote(FieldNote note) =>
      fieldNotesDao.createNote(note);

  Future<void> updateNote(FieldNote note) =>
      fieldNotesDao.updateNote(note);

  Future<void> deleteNote(FieldNote note) =>
      fieldNotesDao.deleteNote(note);
}
