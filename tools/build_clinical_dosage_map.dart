import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  final distinctScientific = db.select(
    "SELECT DISTINCT name_scientific FROM medicines WHERE name_scientific IS NOT NULL AND name_scientific != '';"
  );
  print('Total distinct scientific names in medicines: ${distinctScientific.length}');

  // Read catalog CSV
  final catFile = File('c:\\pharmasy\\PharmaOS\\assets\\data\\medicines_catalog.csv');
  final catLines = catFile.readAsLinesSync();
  print('Total lines in medicines_catalog.csv: ${catLines.length}');

  final Map<String, String> scientificToDosage = {};
  final Map<String, String> nameToDosage = {};

  for (var i = 1; i < catLines.length; i++) {
    final parts = catLines[i].split(',');
    if (parts.length >= 7) {
      final nameEn = parts[0].trim().toLowerCase();
      final nameAr = parts[1].trim();
      final sci = parts[2].trim().toLowerCase();
      final dosage = parts.sublist(6, parts.length - 2).join(',').trim();

      if (dosage.isNotEmpty && dosage.length > 5) {
        if (sci.isNotEmpty) scientificToDosage[sci] = dosage;
        if (nameEn.isNotEmpty) nameToDosage[nameEn] = dosage;
        if (nameAr.isNotEmpty) nameToDosage[nameAr] = dosage;
      }
    }
  }

  print('Loaded ${scientificToDosage.length} scientific dosages and ${nameToDosage.length} name dosages.');

  // Check matching against medicines in DB
  int matched = 0;
  final allMeds = db.select("SELECT id, name_ar, name_en, name_scientific FROM medicines;");
  for (final m in allMeds) {
    final sci = (m['name_scientific'] as String? ?? '').trim().toLowerCase();
    final nameAr = (m['name_ar'] as String? ?? '').trim();
    final nameEn = (m['name_en'] as String? ?? '').trim().toLowerCase();

    if (scientificToDosage.containsKey(sci) || nameToDosage.containsKey(nameEn) || nameToDosage.containsKey(nameAr)) {
      matched++;
    }
  }

  print('Matched medicines with exact dosage text from catalog: $matched / ${allMeds.length}');

  db.dispose();
}
