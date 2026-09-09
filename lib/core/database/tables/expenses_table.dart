import 'package:drift/drift.dart';
import 'users_table.dart';
import 'wallets_table.dart';

@DataClassName('ExpenseRow')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();

  // كهرباء/ماء/إيجار/رواتب/صيانة/نقل/أخرى - راجع docs/WORKFLOW.md
  TextColumn get category => text()();
  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
  IntColumn get workerId => integer().nullable()();
  TextColumn get customWorkerName => text().nullable()();
  
  TextColumn get paymentMethod => text().withDefault(const Constant('نقدي'))(); // 'نقدي', 'محفظة'
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();
  
  IntColumn get recordedBy => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
