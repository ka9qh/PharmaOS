import 'package:drift/drift.dart';
import 'purchases_table.dart';
import 'medicines_table.dart';
import 'batches_table.dart';

@DataClassName('PurchaseItemRow')
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(Purchases, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();

  // كل بند شراء ينشئ دفعة (Batch) جديدة واحدة بالضبط عند الاستلام
  IntColumn get batchId => integer().references(Batches, #id)();

  IntColumn get quantity => integer()(); // الكمية بوحدة الأساس (للمخزون)
  RealColumn get unitCost => real()(); // التكلفة لوحدة الأساس
  RealColumn get subtotal => real()(); // الإجمالي قبل الضريبة
  
  // الضرائب
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))(); // الإجمالي بعد الضريبة

  TextColumn get unitName => text().nullable()(); // حبة، شريط، باكت (للعرض في الفاتورة - قديم)
  IntColumn get conversionFactor => integer().withDefault(const Constant(1))(); // معامل التحويل وقت الشراء
  IntColumn get selectedQuantity => integer().nullable()(); // الكمية التي تم إدخالها بالوحدة المحددة (قديم)
  
  // الاحتفاظ بما أدخله المستخدم بالضبط (لوحدات متعددة في نفس السطر)
  IntColumn get qtyCarton => integer().withDefault(const Constant(0))();
  IntColumn get qtyPack => integer().withDefault(const Constant(0))();
  IntColumn get qtyStrip => integer().withDefault(const Constant(0))();
  IntColumn get qtyPill => integer().withDefault(const Constant(0))();
}
