import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  print('Triggers:');
  final triggers = db.select("SELECT name, sql FROM sqlite_master WHERE type='trigger';");
  for (final t in triggers) {
    print('  ${t['name']}: ${t['sql']}');
  }

  print('FTS tables:');
  final fts = db.select("SELECT name, sql FROM sqlite_master WHERE name LIKE '%fts%';");
  for (final f in fts) {
    print('  ${f['name']}');
  }

  db.dispose();
}
