// جدول سجل التدقيق - PharmaOS
// Append-Only بالكامل: لا توجد أي دالة في النظام تسمح بتعديل أو حذف صف من هذا الجدول.
// راجع docs/AUDIT_LOG_POLICY.md

import 'package:drift/drift.dart';

@DataClassName('AuditLogRow')
class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  IntColumn get userId => integer().nullable()();
  TextColumn get actionType => text()(); // مثال: LOGIN, LOGIN_FAILED, PRICE_UPDATE
  @override
  String get tableName => 'my_table';
  TextColumn get targetTable => text()();
  TextColumn get recordId => text().nullable()();
  TextColumn get oldValue => text().nullable()(); // JSON نصي
  TextColumn get newValue => text().nullable()(); // JSON نصي
  DateTimeColumn get timestamp =>
      dateTime().withDefault(currentDateAndTime)();
}
