import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  print('Running VACUUM to rebuild database file...');
  db.execute('VACUUM;');
  print('✅ VACUUM COMPLETED SUCCESSFULLY!');

  final res = db.select('PRAGMA integrity_check;');
  print('Integrity check: ${res.first.values}');

  db.dispose();
}
