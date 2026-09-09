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

  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  try {
    final rows = db.select('''
      SELECT m.id, IFNULL(SUM(b.quantity), 0) AS total_quantity 
      FROM medicines m 
      LEFT JOIN batches b ON b.medicine_id = m.id 
      GROUP BY m.id 
      HAVING total_quantity > 0
    ''');
    print('Success, count: \${rows.length}');
  } catch(e) { 
    print(e); 
  }

  db.dispose();
}
