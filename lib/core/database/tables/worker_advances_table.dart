import 'package:drift/drift.dart';
import 'workers_table.dart';
import 'users_table.dart';

/// سلف الموظفين
@DataClassName('WorkerAdvanceRow')
class WorkerAdvances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workerId => integer().references(Workers, #id)();
  
  RealColumn get amount => real()(); // مبلغ السلفة
  TextColumn get reason => text().nullable()(); // سبب السلفة
  
  /// هل تم خصمها بالكامل من الرواتب اللاحقة؟
  BoolColumn get isFullyDeducted => boolean().withDefault(const Constant(false))();
  
  /// المبلغ المتبقي من السلفة (يُنقَص كل شهر عند خصمها من الراتب)
  RealColumn get remainingAmount => real()();
  
  TextColumn get paymentMethod => text().withDefault(const Constant('نقدي'))(); // نقدي / محفظة
  
  IntColumn get approvedBy => integer().nullable().references(Users, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
