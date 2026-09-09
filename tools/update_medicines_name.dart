import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final dbPath = '$appData\\com.example\\pharmaos\\pharmaos_secure.db';
  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    print('Database not found at $dbPath');
    return;
  }

  print('Updating Medicines table to show Arabic and English names...');
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  try {
    db.execute('''
      UPDATE Medicines 
      SET name_ar = name_ar || ' (' || name_en || ')' 
      WHERE name_en IS NOT NULL 
        AND name_ar NOT LIKE '%(%';
    ''');
    print('Medicines table updated successfully.');
  } catch (e) {
    print('Error updating Medicines: $e');
  }

  db.dispose();
}
