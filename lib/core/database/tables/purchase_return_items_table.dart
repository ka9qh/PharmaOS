import 'package:drift/drift.dart';
import 'purchase_returns_table.dart';
import 'medicines_table.dart';
import 'batches_table.dart';

@DataClassName('PurchaseReturnItemRow')
class PurchaseReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(PurchaseReturns, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  IntColumn get batchId => integer().references(Batches, #id)(); // يجب إرجاع دفعة محددة لسحب المخزون بشكل صحيح
  
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()(); // سعر الشراء المرتجع به
  RealColumn get subtotal => real()();
  TextColumn get reason => text().withDefault(const Constant('منتهي الصلاحية'))();
  
  // الاحتفاظ بما أدخله المستخدم بالضبط (لوحدات متعددة في نفس السطر)
  IntColumn get qtyCarton => integer().withDefault(const Constant(0))();
  IntColumn get qtyPack => integer().withDefault(const Constant(0))();
  IntColumn get qtyStrip => integer().withDefault(const Constant(0))();
  IntColumn get qtyPill => integer().withDefault(const Constant(0))();
}
