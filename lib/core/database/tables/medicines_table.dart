import 'package:drift/drift.dart';
import 'categories_table.dart';
import 'companies_table.dart';
import 'suppliers_table.dart';

@DataClassName('MedicineRow')
class Medicines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  TextColumn get nameAr => text().withLength(min: 1, max: 150)();
  TextColumn get nameEn => text().nullable()();
  TextColumn get nameScientific => text().nullable()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get companyId =>
      integer().nullable().references(Companies, #id)();
  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id)();

  // يُنشأ تلقائيًا عبر core/utils/barcode_generator.dart - راجع WORKFLOW.md
  TextColumn get sku => text()();
  TextColumn get barcode => text()();

  TextColumn get unit => text().withDefault(const Constant('حبة'))();
  IntColumn get medicineType => integer().withDefault(const Constant(0))(); // 0: None, 1: Pills, 2: Injections, 3: Glass, 4: Diapers, 5: Cosmetics
  RealColumn get purchasePrice => real()(); // سعر شراء الحبة
  RealColumn get sellingPrice => real()(); // سعر بيع الحبة
  IntColumn get qtyPerStrip => integer().nullable()();
  RealColumn get stripPurchasePrice => real().nullable()();
  RealColumn get stripSellingPrice => real().nullable()();
  IntColumn get qtyPerPack => integer().nullable()();
  RealColumn get packPurchasePrice => real().nullable()();
  RealColumn get packSellingPrice => real().nullable()();
  IntColumn get qtyPerCarton => integer().nullable()();
  RealColumn get cartonPurchasePrice => real().nullable()();
  RealColumn get cartonSellingPrice => real().nullable()();
  TextColumn get reserveField1 => text().nullable()();
  TextColumn get reserveField2 => text().nullable()();
  TextColumn get reserveField3 => text().nullable()();

  // حد التنبيه لنقص المخزون - راجع docs/WORKFLOW.md و features/inventory
  IntColumn get reorderLevel => integer().withDefault(const Constant(5))();

  // الضرائب
  BoolColumn get isTaxable => boolean().withDefault(const Constant(true))();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {sku},
        {barcode},
      ];
}
