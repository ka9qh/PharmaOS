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
    print('--- Categories ---');
    final c = db.select('SELECT id, name FROM Categories LIMIT 5');
    for(var row in c) { print(row); }

    print('\\n--- Companies ---');
    final comp = db.select('SELECT id, name FROM Companies LIMIT 5');
    for(var row in comp) { print(row); }

    print('\\n--- Medicines ---');
    final m = db.select('SELECT id, name_ar, name_en FROM Medicines LIMIT 5');
    for(var row in m) { print(row); }

    print('\\n--- Inventory Count ---');
    final inv = db.select('''
      SELECT COUNT(*) as cnt FROM medicines m 
      LEFT JOIN batches b ON b.medicine_id = m.id 
      GROUP BY m.id 
      HAVING IFNULL(SUM(b.quantity), 0) > 0
    ''');
    print('Active inventory items with quantity > 0: \${inv.length}');
  } catch(e) {
    print(e);
  }
  db.dispose();
}
