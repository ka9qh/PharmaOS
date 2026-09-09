import 'package:drift/drift.dart';

// جدول ملاحظات الأصناف المطلوبة غير المتوفرة (Step 22)
// يسمح لصاحب الصيدلية بتدوين الأصناف التي يطلبها الزبائن
// ولا تتوفر حاليًا، مع إرسال تذكيرات عبر نظام الإشعارات.
@DataClassName('NeededItemRow')
class NeededItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemName => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get customerName => text().nullable()();
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}
