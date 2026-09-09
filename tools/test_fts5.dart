import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pharmaos/core/database/app_database.dart';

void main() async {
  // Mock path provider for Dart CLI
  final dbFolder = Directory(Platform.environment['APPDATA']! + '\\com.example\\pharmaos');
  final file = File(p.join(dbFolder.path, 'pharmaos_secure.db'));

  final db = AppDatabase.forTesting(NativeDatabase(
    file,
    setup: (rawDb) {
      rawDb.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");
    },
  ));

  print('Migration starting...');
  // Force migration check (it will trigger _rebuildFTS if from < 14)
  final meds = await (db.select(db.medicines)..limit(1)).get();
  print('Migration completed. Fetched sample medicine: ${meds.isNotEmpty ? meds.first.nameAr : "None"}');

  // Test FTS search
  print('--- Testing FTS5 Search ---');
  final searchQueries = ['123', '3v', 'TRICAN']; // Partial barcode/English names
  
  for (var query in searchQueries) {
    print('Searching for: \$query');
    final ids = await db.searchMedicineIdsFast(query);
    print('Found IDs: \$ids');
    if (ids.isNotEmpty) {
      final results = await (db.select(db.medicines)..where((m) => m.id.isIn(ids))).get();
      for (var r in results) {
        print('  - \${r.nameAr} | \${r.nameEn} | \${r.barcode} | \${r.reserveField1}');
      }
    }
  }

  exit(0);
}
