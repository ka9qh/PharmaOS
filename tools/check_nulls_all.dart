import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final dbPath = '$appData\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  try {
    final cols = ['id', 'name_ar', 'sku', 'barcode', 'unit', 'purchase_price', 'selling_price', 'reorder_level', 'is_active', 'medicine_type', 'is_taxable', 'tax_rate', 'created_at', 'updated_at'];
    for (var col in cols) {
      final res = db.select('SELECT COUNT(*) as c FROM medicines WHERE $col IS NULL');
      if (res.first['c'] > 0) {
        print('FOUND NULL in $col: ${res.first['c']} rows!');
      }
    }
    print('Check finished.');
  } catch(e) {
    print(e);
  }
  db.dispose();
}
