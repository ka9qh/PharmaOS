import 'package:drift/drift.dart';
import 'sales_table.dart';
import 'medicines_table.dart';
import 'batches_table.dart';

@DataClassName('SaleItemRow')
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();

  // قد يكون أكثر من صف SaleItem لنفس الدواء في نفس الفاتورة إذا استُهلكت
  // الكمية من أكثر من دفعة (Batch) واحدة بمنطق FEFO - راجع docs/WORKFLOW.md
  IntColumn get batchId => integer().nullable().references(Batches, #id)();

  IntColumn get quantity => integer()(); // الكمية بوحدة الأساس (التي تُخصم من الدفعة)
  RealColumn get unitPrice => real()(); // سعر الوحدة المحددة (مثلاً سعر الباكت)
  RealColumn get subtotal => real()(); // السعر الإجمالي قبل الضريبة والخصم
  
  // الضرائب
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))(); // الإجمالي بعد الضريبة

  // حماية البيانات التاريخية
  TextColumn get unitName => text().nullable()(); // حبة، شريط، باكت (للعرض في الفاتورة)
  IntColumn get conversionFactor => integer().withDefault(const Constant(1))(); // معامل التحويل وقت البيع
  IntColumn get selectedQuantity => integer().nullable()(); // الكمية التي تم إدخالها بالوحدة المحددة
}
