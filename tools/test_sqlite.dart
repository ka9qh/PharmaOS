import 'package:sqlite3/sqlite3.dart';

void main() {
  print('Using sqlite3 ${sqlite3.version}');
  final db = sqlite3.open('data/pharmaos_dev.db');
  
  final countMedicines = db.select('SELECT count(*) as c FROM medicines;');
  print('Medicines count: ${countMedicines.first['c']}');
  
  final countGL = db.select('SELECT count(*) as c FROM journal_entries;');
  print('Journal Entries count: ${countGL.first['c']}');
  
  db.dispose();
}
