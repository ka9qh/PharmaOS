import 'package:drift/drift.dart';
import 'workers_table.dart';
import 'users_table.dart';

/// كشوف الرواتب الشهرية
@DataClassName('PayrollRow')
class Payroll extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workerId => integer().references(Workers, #id)();
  
  IntColumn get month => integer()(); // الشهر (1-12)
  IntColumn get year => integer()(); // السنة
  
  RealColumn get baseSalary => real()(); // الراتب الأساسي
  RealColumn get totalAllowances => real().withDefault(const Constant(0))(); // إجمالي البدلات
  RealColumn get totalDeductions => real().withDefault(const Constant(0))(); // إجمالي الخصومات (سلف، غيابات)
  RealColumn get totalAdvancesDeducted => real().withDefault(const Constant(0))(); // السلف المخصومة هذا الشهر
  RealColumn get daysWorked => real().withDefault(const Constant(0))(); // أيام العمل
  RealColumn get daysAbsent => real().withDefault(const Constant(0))(); // أيام الغياب
  RealColumn get netSalary => real()(); // صافي الراتب بعد الخصومات
  
  TextColumn get paymentMethod => text().withDefault(const Constant('نقدي'))(); // نقدي / محفظة
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, paid
  
  IntColumn get paidBy => integer().nullable().references(Users, #id)();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {workerId, month, year}, // كشف واحد لكل موظف في الشهر
  ];
}
