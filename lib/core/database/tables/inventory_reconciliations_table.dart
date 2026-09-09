import 'package:drift/drift.dart';
import 'users_table.dart';
import 'medicines_table.dart';

@DataClassName('InventoryReconciliationRow')
class InventoryReconciliations extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // من قام بالتسوية
  IntColumn get userId => integer().nullable().references(Users, #id)();
  
  // الدواء الذي تم جرده
  IntColumn get medicineId => integer().references(Medicines, #id)();
  
  // الكمية الدفترية (حسب النظام) قبل الجرد
  RealColumn get systemQuantity => real()();
  
  // الكمية الفعلية (التي وجدها المستخدم في الرف)
  RealColumn get actualQuantity => real()();
  
  // الفرق (الفعلي - الدفتري). الموجب يعني زيادة في المخزن، السالب يعني عجز
  RealColumn get difference => real()();
  
  // السبب أو الملاحظة (تالف، مسروق، خطأ إدخال سابق، الخ)
  TextColumn get note => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
