// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'field_notes_dao.dart';

// ignore_for_file: type=lint
mixin _$FieldNotesDaoMixin on DatabaseAccessor<AppDatabase> {
  $FieldNotesTable get fieldNotes => attachedDatabase.fieldNotes;
  $SyncOutboxTable get syncOutbox => attachedDatabase.syncOutbox;
  FieldNotesDaoManager get managers => FieldNotesDaoManager(this);
}

class FieldNotesDaoManager {
  final _$FieldNotesDaoMixin _db;
  FieldNotesDaoManager(this._db);
  $$FieldNotesTableTableManager get fieldNotes =>
      $$FieldNotesTableTableManager(_db.attachedDatabase, _db.fieldNotes);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db.attachedDatabase, _db.syncOutbox);
}
