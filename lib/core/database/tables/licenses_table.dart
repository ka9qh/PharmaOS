import 'package:drift/drift.dart';

// بيانات الترخيص المُفعَّل محليًا - راجع docs/LICENSING_STRATEGY.md
@DataClassName('LicenseRow')
class Licenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  TextColumn get hardwareId => text()();
  TextColumn get licenseKey => text()();
  TextColumn get pharmacyName => text()();
  DateTimeColumn get activatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime().nullable()();
}
