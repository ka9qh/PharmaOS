import 'package:drift/drift.dart';
import 'returns_table.dart';
import 'medicines_table.dart';
import 'sale_items_table.dart';
import 'purchase_items_table.dart';

// originalSaleItemId/originalPurchaseItemId يسمحان بالتحقق من عدم إرجاع كمية
// أكبر مما بيع/اشتُري فعليًا في ذلك السطر بالضبط (حتى لو تكرر الإرجاع مرتين).
@DataClassName('ReturnItemRow')
class ReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(Returns, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get subtotal => real()();
  IntColumn get originalSaleItemId =>
      integer().nullable().references(SaleItems, #id)();
  IntColumn get originalPurchaseItemId =>
      integer().nullable().references(PurchaseItems, #id)();
      
  IntColumn get qtyCarton => integer().withDefault(const Constant(0))();
  IntColumn get qtyPack => integer().withDefault(const Constant(0))();
  IntColumn get qtyStrip => integer().withDefault(const Constant(0))();
  IntColumn get qtyPill => integer().withDefault(const Constant(0))();
}
