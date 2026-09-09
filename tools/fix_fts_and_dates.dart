import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  print('Dropping FTS triggers and table...');
  db.execute("DROP TRIGGER IF EXISTS medicines_fts_ai;");
  db.execute("DROP TRIGGER IF EXISTS medicines_fts_ad;");
  db.execute("DROP TRIGGER IF EXISTS medicines_fts_au;");
  db.execute("DROP TABLE IF EXISTS medicines_fts;");
  print('FTS dropped successfully.');

  print('Updating datetime columns across all tables...');
  // Fix medicines
  db.execute("UPDATE medicines SET updated_at = strftime('%s', updated_at) WHERE typeof(updated_at) = 'text' AND updated_at LIKE '%-%';");
  db.execute("UPDATE medicines SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");

  // Fix categories
  db.execute("UPDATE categories SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");

  // Fix companies
  db.execute("UPDATE companies SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");

  // Fix suppliers
  db.execute("UPDATE suppliers SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");

  // Fix sales
  db.execute("UPDATE sales SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");

  // Fix expenses
  db.execute("UPDATE expenses SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");

  // Fix returns
  db.execute("UPDATE returns SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");

  // Fix day_closings
  db.execute("UPDATE day_closings SET date = strftime('%s', date) WHERE typeof(date) = 'text' AND date LIKE '%-%';");
  db.execute("UPDATE day_closings SET period_start = strftime('%s', period_start) WHERE typeof(period_start) = 'text' AND period_start LIKE '%-%';");
  db.execute("UPDATE day_closings SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");

  // Fix accounts
  db.execute("UPDATE accounts SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");
  db.execute("UPDATE accounts SET updated_at = strftime('%s', updated_at) WHERE typeof(updated_at) = 'text' AND updated_at LIKE '%-%';");

  // Fix journal_entries
  db.execute("UPDATE journal_entries SET date = strftime('%s', date) WHERE typeof(date) = 'text' AND date LIKE '%-%';");
  db.execute("UPDATE journal_entries SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text' AND created_at LIKE '%-%';");
  db.execute("UPDATE journal_entries SET updated_at = strftime('%s', updated_at) WHERE typeof(updated_at) = 'text' AND updated_at LIKE '%-%';");

  print('All datetime columns converted to UNIX epoch integers successfully!');

  // Verify
  final medTest = db.select("SELECT id, created_at, updated_at, typeof(created_at), typeof(updated_at) FROM medicines LIMIT 3;");
  for (final r in medTest) {
    print('MED: ${r['id']} | created: ${r['created_at']} (${r['typeof(created_at)']}) | updated: ${r['updated_at']} (${r['typeof(updated_at)']})');
  }

  final catTest = db.select("SELECT id, created_at, typeof(created_at) FROM categories LIMIT 3;");
  for (final r in catTest) {
    print('CAT: ${r['id']} | created: ${r['created_at']} (${r['typeof(created_at)']})');
  }

  final compTest = db.select("SELECT id, created_at, typeof(created_at) FROM companies LIMIT 3;");
  for (final r in compTest) {
    print('COMP: ${r['id']} | created: ${r['created_at']} (${r['typeof(created_at)']})');
  }

  db.dispose();
}
