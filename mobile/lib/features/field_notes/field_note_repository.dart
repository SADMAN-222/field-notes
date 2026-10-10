import '../../core/database/database.dart';
import '../../core/database/daos/field_notes_dao.dart';

class FieldNoteRepository {
  final FieldNotesDao fieldNotesDao;
  
  FieldNoteRepository({required this.fieldNotesDao});

  Stream<List<FieldNote>> watchNotes(String siteId) => fieldNotesDao.watchNotesBySite(siteId);
  Stream<List<FieldNote>> watchAllNotes(String userId) => fieldNotesDao.watchAllNotes(userId);
  
  Future<void> addNote(FieldNote note) => fieldNotesDao.createNote(note);
  
  Future<void> updateNote(FieldNote note) => fieldNotesDao.updateNote(note);
  
  Future<void> deleteNote(FieldNote note) => fieldNotesDao.deleteNote(note);
}

