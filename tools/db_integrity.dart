import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  final res = db.select('PRAGMA integrity_check;');
  for (final r in res) {
    print(r.values);
  }

  db.dispose();
}
