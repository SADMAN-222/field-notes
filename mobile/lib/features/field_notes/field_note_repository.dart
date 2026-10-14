import 'package:flutter/foundation.dart';
import '../../core/database/database.dart';
import '../../core/database/daos/field_notes_dao.dart';

class FieldNoteRepository {
  final FieldNotesDao fieldNotesDao;

  FieldNoteRepository({required this.fieldNotesDao});

  Stream<List<FieldNote>> watchNotes(String siteId, String userId) =>
      fieldNotesDao.watchNotesBySite(siteId, userId);

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

  Future<FieldNote?> getNoteById(String id, String userId) =>
      fieldNotesDao.getNoteById(id, userId);

  Stream<FieldNote?> watchNoteById(String id, String userId) =>
      fieldNotesDao.watchNoteById(id, userId);

  Future<int> getNotesCount(String userId, {String? status}) =>
      fieldNotesDao.getNotesCount(userId, status: status);

  Future<void> addNote(FieldNote note, String userId) {
    if (note.userId != userId) {
      throw StateError('Field note does not belong to the active account.');
    }
    debugPrint('FieldNoteRepository.addNote: ${note.userId}, ID: ${note.id}, Site: ${note.siteId}');
    return fieldNotesDao.createNote(note);
  }

  Future<void> updateNote(FieldNote note, String userId) {
    if (note.userId != userId) {
      throw StateError('Field note does not belong to the active account.');
    }
    return fieldNotesDao.updateNote(note);
  }

  Future<void> deleteNote(FieldNote note, String userId) {
    if (note.userId != userId) {
      throw StateError('Field note does not belong to the active account.');
    }
    return fieldNotesDao.deleteNote(note);
  }
}
