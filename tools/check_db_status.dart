import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final file = File(dbPath);
  if (!file.existsSync()) {
    print('Database file does not exist at: $dbPath');
    return;
  }
  print('=== PharmaOS Database Health & Completeness Audit ===');
  print('DB Path: $dbPath');
  print('File Size: ${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB (${file.lengthSync()} bytes)');

  final db = sqlite3.open(dbPath);

  final tables = [
    'medicines',
    'batches',
    'barcode_bindings',
    'suppliers',
    'customers',
    'users',
    'sales',
    'sale_items',
    'purchases',
    'purchase_items',
    'expenses',
    'vendor_payments',
    'settings',
    'closing_shifts'
  ];

  for (final table in tables) {
    try {
      final res = db.select('SELECT COUNT(*) as cnt FROM $table');
      final count = res.first['cnt'];
      print('✅ Table [$table]: $count rows');
    } catch (e) {
      print('⚠️ Table [$table]: not found or error ($e)');
    }
  }

  // Check medicines with scientific names (alternatives)
  try {
    final altRes = db.select("SELECT COUNT(*) as cnt FROM medicines WHERE scientific_name IS NOT NULL AND scientific_name != ''");
    print('🔍 Medicines with Active Ingredient (Scientific Name for Alternatives): ${altRes.first['cnt']}');
  } catch (_) {}

  // Check active batches
  try {
    final batchRes = db.select("SELECT COUNT(*) as cnt FROM batches WHERE quantity > 0");
    print('📦 Active Batches in Stock (FEFO ready): ${batchRes.first['cnt']}');
  } catch (_) {}

  db.dispose();
  print('=====================================================');
}
