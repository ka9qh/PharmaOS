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

  print('Database exists at $dbPath');
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");
  
  try {
    final result = db.select('SELECT COUNT(*) as c FROM Medicines;');
    print('Medicines Count: ${result.first['c']}');
  } catch (e) {
    print('Error querying Medicines: $e');
  }

  db.dispose();
}
