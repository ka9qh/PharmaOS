import 'package:drift/drift.dart';

@DataClassName('SupplierRow')
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get nameEn => text().nullable()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get shortName => text().nullable()();
  TextColumn get representedCompanies => text().nullable()();
  TextColumn get contactInfo => text().nullable()(); // هاتف/واتساب المندوب مثلاً
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name},
      ];
}
