import 'package:drift/drift.dart';

@DataClassName('UiString')
class UiStrings extends Table {
  TextColumn get keyName => text()();
  TextColumn get valueAr => text()();
  TextColumn get module => text().nullable()(); // e.g. 'dashboard', 'pos'
  
  @override
  Set<Column> get primaryKey => {keyName};
}
