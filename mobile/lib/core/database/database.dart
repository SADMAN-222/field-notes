import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Customers, Sites, FieldNotes, SyncOutbox, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await customStatement(
          "UPDATE field_notes SET status = CASE status "
          "WHEN 'DRAFT' THEN 'PENDING' "
          "WHEN 'SUBMITTED' THEN 'IN_PROGRESS' "
          "ELSE status END "
          "WHERE status IN ('DRAFT', 'SUBMITTED')",
        );
      }
    },
  );

  Future<void> clearAccountData(String userId) async {
    final photoPaths = (await (select(fieldNotes)
          ..where((row) => row.userId.equals(userId)))
        .get())
        .map((note) => note.photoPath)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();

    await transaction(() async {
      await (delete(syncOutbox)
            ..where((row) => row.payload.like('%"userId":"$userId"%')))
          .go();
      await (delete(fieldNotes)..where((row) => row.userId.equals(userId))).go();
      await (delete(sites)..where((row) => row.userId.equals(userId))).go();
      await (delete(customers)..where((row) => row.userId.equals(userId))).go();
      await (delete(syncMetadata)
            ..where((row) => row.id.equals('cursor:$userId')))
          .go();
    });

    final documents = await getApplicationDocumentsDirectory();
    final ownedPhotoDirectory = p.normalize(
      p.join(documents.path, 'photos'),
    );
    for (final photoPath in photoPaths) {
      final file = File(p.normalize(photoPath));
      if (p.isWithin(ownedPhotoDirectory, file.path) &&
          await file.exists()) {
        await file.delete();
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
