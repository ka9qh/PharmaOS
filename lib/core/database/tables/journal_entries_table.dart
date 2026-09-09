import 'package:drift/drift.dart';
import 'users_table.dart';

@DataClassName('JournalEntryRow')
class JournalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // رقم القيد (مثلاً JE-2026-0001) لسهولة التتبع
  TextColumn get referenceNumber => text().unique()();
  
  // تاريخ القيد
  DateTimeColumn get date => dateTime()();
  
  // وصف أو بيان القيد بشكل عام (مثل: إثبات مبيعات يوم كذا، أو فاتورة شراء كذا)
  TextColumn get description => text()();
  
  // مصدر القيد (Sales, Purchases, Manual, Return, DayClosing) لمعرفة من أين تم توليده
  TextColumn get source => text().withDefault(const Constant('Manual'))();
  
  // المعرف المرتبط في الجدول المصدر (مثلاً رقم الفاتورة) إن وجد
  IntColumn get sourceId => integer().nullable()();
  
  // هل القيد مرحل أم مسودة؟ (في حالتنا سنعتبره مرحلاً فوراً unless specified)
  TextColumn get status => text().withDefault(const Constant('posted'))();

  // المستخدم الذي أنشأ القيد
  IntColumn get createdBy => integer().nullable().references(Users, #id)();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
