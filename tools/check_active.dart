import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final dbPath = '$appData\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  try {
    final res = db.select('SELECT COUNT(*) as c FROM medicines WHERE is_active = 1');
    print('Active medicines: ${res.first['c']}');
    
    final all = db.select('SELECT COUNT(*) as c FROM medicines');
    print('All medicines: ${all.first['c']}');
    
    final typeCheck = db.select('SELECT typeof(is_active) as t, is_active FROM medicines LIMIT 1');
    print('is_active type: ${typeCheck.first['t']}, value: ${typeCheck.first['is_active']}');
  } catch(e) {
    print(e);
  }
  db.dispose();
}
