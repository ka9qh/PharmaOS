import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  final userRes = db.select('SELECT id, created_at, typeof(created_at) FROM users LIMIT 3;');
  for (final r in userRes) {
    print('USER: ${r['id']} | created_at: ${r['created_at']} | type: ${r['typeof(created_at)']}');
  }

  final medRes = db.select('SELECT id, created_at, updated_at, typeof(created_at), typeof(updated_at) FROM medicines LIMIT 5;');
  for (final r in medRes) {
    print('MED: ${r['id']} | created: ${r['created_at']} (${r['typeof(created_at)']}) | updated: ${r['updated_at']} (${r['typeof(updated_at)']})');
  }

  db.dispose();
}
