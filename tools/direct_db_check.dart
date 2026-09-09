import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pharmaos/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  final db = AppDatabase(NativeDatabase(sqlite3.open('data/pharmaos_dev.db')));
  final count = await db.select(db.medicines).get();
  print('Total medicines: ${count.length}');
}
