import 'dart:ffi';
import 'dart:io';
import 'package:sqlite3/open.dart';

void setupSqliteForTest() {
  if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, () {
      final localFile = File('sqlite3.dll');
      if (localFile.existsSync()) {
        return DynamicLibrary.open(localFile.absolute.path);
      }
      return DynamicLibrary.open('sqlite3.dll');
    });
  }
}

