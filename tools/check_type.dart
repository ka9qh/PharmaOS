import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final dbPath = '$appData\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  try {
    final typeCheck = db.select('SELECT typeof(medicine_type) as t, medicine_type FROM medicines LIMIT 10');
    for(var row in typeCheck) {
      print('medicine_type type: ${row['t']}, value: ${row['medicine_type']}');
    }
  } catch(e) {
    print(e);
  }
  db.dispose();
}
