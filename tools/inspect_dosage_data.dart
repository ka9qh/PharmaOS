import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  print('--- Checking reserve fields in medicines table ---');
  final db = sqlite3.open('C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db');
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  final sampleWithReserve = db.select(
    "SELECT id, name_ar, name_en, name_scientific, reserve_field1, reserve_field2, reserve_field3 FROM medicines WHERE reserve_field1 IS NOT NULL AND LENGTH(reserve_field1) > 10 LIMIT 5;"
  );
  for (final r in sampleWithReserve) {
    print('\nMED ID ${r['id']}: ${r['name_ar']} (${r['name_en']})');
    print('  Scientific: ${r['name_scientific']}');
    print('  Reserve 1: ${r['reserve_field1']}');
    print('  Reserve 2: ${r['reserve_field2']}');
    print('  Reserve 3: ${r['reserve_field3']}');
  }

  final res1Count = db.select("SELECT COUNT(*) as c FROM medicines WHERE reserve_field1 IS NOT NULL AND reserve_field1 != '';").first['c'];
  final res2Count = db.select("SELECT COUNT(*) as c FROM medicines WHERE reserve_field2 IS NOT NULL AND reserve_field2 != '';").first['c'];
  final res3Count = db.select("SELECT COUNT(*) as c FROM medicines WHERE reserve_field3 IS NOT NULL AND reserve_field3 != '';").first['c'];
  print('\nMedicines with reserve_field1: $res1Count');
  print('Medicines with reserve_field2: $res2Count');
  print('Medicines with reserve_field3: $res3Count');

  db.dispose();

  print('\n--- Checking all CSV and Excel files in assets/data and Desktop ---');
  final dirsToCheck = [
    Directory('c:\\pharmasy\\PharmaOS\\assets\\data'),
    Directory('C:\\Users\\hp\\Desktop'),
  ];

  for (final dir in dirsToCheck) {
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        if (f is File && (f.path.endsWith('.csv') || f.path.endsWith('.xlsx') || f.path.endsWith('.xls'))) {
          print('\nFILE: ${f.path}');
          if (f.path.endsWith('.csv')) {
            try {
              final lines = f.readAsLinesSync();
              print('  Total lines: ${lines.length}');
              if (lines.isNotEmpty) {
                print('  Header: ${lines.first}');
                for (var i = 1; i <= (lines.length > 3 ? 3 : lines.length - 1); i++) {
                  print('  Sample $i: ${lines[i].length > 120 ? lines[i].substring(0, 120) + "..." : lines[i]}');
                }
              }
            } catch (e) {
              print('  Error reading csv: $e');
            }
          }
        }
      }
    }
  }
}
