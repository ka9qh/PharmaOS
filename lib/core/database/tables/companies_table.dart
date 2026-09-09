import 'package:drift/drift.dart';

@DataClassName('CompanyRow')
class Companies extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get nameEn => text().nullable()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get countryAr => text().nullable()();
  TextColumn get countryEn => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name},
      ];
}
