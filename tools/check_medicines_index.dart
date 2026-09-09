import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  print('Indexes on medicines:');
  final indexes = db.select("PRAGMA index_list(medicines);");
  for (final idx in indexes) {
    print('  Index: ${idx['name']}');
  }

  print('\nChecking REINDEX...');
  try {
    db.execute('REINDEX medicines;');
    print('REINDEX medicines SUCCESSFUL!');
  } catch (e) {
    print('REINDEX failed: $e');
  }

  db.dispose();
}
