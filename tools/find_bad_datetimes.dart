import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  print('Inspecting database: $dbPath');

  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  final tablesResult = db.select("SELECT name FROM sqlite_master WHERE type='table';");
  for (final row in tablesResult) {
    final tableName = row['name'] as String;
    if (tableName.startsWith('sqlite_') || tableName.contains('fts')) continue;

    try {
      final pragmaResult = db.select("PRAGMA table_info($tableName);");
      for (final col in pragmaResult) {
        final colName = col['name'] as String;
        final colType = col['type'] as String;

        // Check if there are rows where this column contains ':' or '-'
        try {
          final badRows = db.select(
            "SELECT id, $colName FROM $tableName WHERE typeof($colName) = 'text' AND $colName LIKE '%:%' LIMIT 5;"
          );
          if (badRows.isNotEmpty) {
            print('TABLE [$tableName], COLUMN [$colName] (declared as $colType):');
            for (final r in badRows) {
              print('  id: ${r['id']}, value: "${r[colName]}"');
            }
          }
        } catch (_) {
          // Some tables might not have 'id' column
          try {
            final badRows = db.select(
              "SELECT rowid, $colName FROM $tableName WHERE typeof($colName) = 'text' AND $colName LIKE '%:%' LIMIT 5;"
            );
            if (badRows.isNotEmpty) {
              print('TABLE [$tableName], COLUMN [$colName] (declared as $colType):');
              for (final r in badRows) {
                print('  rowid: ${r['rowid']}, value: "${r[colName]}"');
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print('Error inspecting table $tableName: $e');
    }
  }

  db.dispose();
  print('Inspection done.');
}
