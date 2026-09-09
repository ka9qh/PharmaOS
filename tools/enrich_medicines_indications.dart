import 'dart:io';
import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  print('Reading Scientific_all.csv for active ingredient uses...');
  final sciFile = File('c:\\pharmasy\\PharmaOS\\assets\\data\\Scientific_all.csv');
  final Map<String, String> sciUses = {};

  if (sciFile.existsSync()) {
    final lines = sciFile.readAsLinesSync();
    for (var i = 1; i < lines.length; i++) {
      final parts = const CsvToListConverter().convert(lines[i]);
      if (parts.isNotEmpty && parts.first.length >= 5) {
        final sciEn = parts.first[1].toString().trim().toLowerCase();
        final sciAr = parts.first[2].toString().trim();
        final useAr = parts.first[4].toString().trim();
        final useEn = parts.first[3].toString().trim();

        final bestUse = useAr.isNotEmpty ? useAr : useEn;
        if (bestUse.isNotEmpty && bestUse.length > 5) {
          if (sciAr.isNotEmpty) sciUses[sciAr] = bestUse;
          if (sciEn.isNotEmpty) sciUses[sciEn] = bestUse;
        }
      }
    }
  }

  print('Loaded ${sciUses.length} scientific uses.');

  // Update medicines where reserve_field1 is generic or empty
  final stmt = db.prepare("UPDATE medicines SET reserve_field1 = ? WHERE id = ?;");

  final meds = db.select("SELECT id, name_ar, name_en, name_scientific, reserve_field1 FROM medicines;");
  int updatedCount = 0;

  for (final m in meds) {
    final id = m['id'] as int;
    final sci = (m['name_scientific'] as String? ?? '').trim();
    final currentRes = (m['reserve_field1'] as String? ?? '').trim();

    if (sci.isNotEmpty && (currentRes.isEmpty || currentRes.startsWith('علاج يحتوي على'))) {
      final use = sciUses[sci] ?? sciUses[sci.toLowerCase()];
      if (use != null && use.isNotEmpty) {
        stmt.execute([use, id]);
        updatedCount++;
      }
    }
  }

  stmt.dispose();
  print('✅ Successfully enriched $updatedCount medicines with detailed clinical indications in database!');

  db.dispose();
}
