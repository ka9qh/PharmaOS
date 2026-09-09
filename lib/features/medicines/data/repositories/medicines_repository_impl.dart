import 'package:drift/drift.dart' show Value;

import '../../domain/entities/medicines_entity.dart';
import '../../domain/repositories/medicines_repository.dart';
import '../datasources/medicines_datasource.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/barcode_generator.dart';
import '../../../../core/security/audit_logger.dart';
import '../../../categories/domain/repositories/categories_repository.dart';
import '../../../companies/domain/repositories/companies_repository.dart';
import '../../../suppliers/domain/repositories/suppliers_repository.dart';

class MedicinesRepositoryImpl implements MedicinesRepository {
  final MedicinesDataSource dataSource;
  final CategoriesRepository categoriesRepository;
  final CompaniesRepository companiesRepository;
  final SuppliersRepository suppliersRepository;
  final AuditLogger auditLogger;

  MedicinesRepositoryImpl({
    required this.dataSource,
    required this.categoriesRepository,
    required this.companiesRepository,
    required this.suppliersRepository,
    required this.auditLogger,
  });

  MedicineEntity _mapRow(
    MedicineRow row,
    Map<int, String> categoryNames,
    Map<int, String> companyNames,
    Map<int, String> supplierNames,
  ) {
    return MedicineEntity(
      id: row.id,
      nameAr: row.nameAr,
      nameEn: row.nameEn,
      nameScientific: row.nameScientific,
      categoryId: row.categoryId,
      categoryName: row.categoryId != null ? categoryNames[row.categoryId] : null,
      companyId: row.companyId,
      companyName: row.companyId != null ? companyNames[row.companyId] : null,
      supplierId: row.supplierId,
      supplierName: row.supplierId != null ? supplierNames[row.supplierId] : null,
      sku: row.sku,
      barcode: row.barcode,
      unit: row.unit,
      purchasePrice: row.purchasePrice,
      sellingPrice: row.sellingPrice,
      qtyPerPack: row.qtyPerPack,
      qtyPerStrip: row.qtyPerStrip,
      qtyPerCarton: row.qtyPerCarton,
      packPurchasePrice: row.packPurchasePrice,
      packSellingPrice: row.packSellingPrice,
      stripPurchasePrice: row.stripPurchasePrice,
      stripSellingPrice: row.stripSellingPrice,
      cartonPurchasePrice: row.cartonPurchasePrice,
      cartonSellingPrice: row.cartonSellingPrice,
      reorderLevel: row.reorderLevel,
      isActive: row.isActive,
      reserveField1: row.reserveField1,
      reserveField2: row.reserveField2,
      reserveField3: row.reserveField3,
      medicineType: row.medicineType,
    );
  }

  Future<Map<int, String>> _categoryNameMap() async {
    final categories = await categoriesRepository.getAll();
    return {for (final c in categories) c.id: c.name};
  }

  Future<Map<int, String>> _companyNameMap() async {
    final companies = await companiesRepository.getAll();
    return {for (final c in companies) c.id: c.name};
  }

  Future<Map<int, String>> _supplierNameMap() async {
    final suppliers = await suppliersRepository.getAll();
    return {for (final s in suppliers) s.id: s.name};
  }



  @override
  Future<List<MedicineEntity>> getAll({String? searchQuery}) async {
    // تحديث أداء: الفلترة تتم الآن داخل SQL (فهرس/FTS5) عبر
    // MedicinesDataSource بدلًا من جلب كل الجدول وفلترته هنا في الذاكرة -
    // ضروري لدعم مخزون كبير (100,000+ دواء) بسرعة استجابة مقبولة.
    final rows = await dataSource.getAll(searchQuery: searchQuery);
    final categoryNames = await _categoryNameMap();
    final companyNames = await _companyNameMap();
    final supplierNames = await _supplierNameMap();
    
    final validEntities = <MedicineEntity>[];
    for (final r in rows) {
      try {
        validEntities.add(_mapRow(r, categoryNames, companyNames, supplierNames));
      } catch (e) {
        // Log locally and continue to prevent the whole screen from crashing
        print('Error mapping medicine ID ${r.id}: $e');
      }
    }
    return validEntities;
  }

  @override
  Future<MedicineEntity?> getByBarcode(String barcode) async {
    final row = await dataSource.getByBarcode(barcode);
    if (row == null) return null;
    final categoryNames = await _categoryNameMap();
    final companyNames = await _companyNameMap();
    final supplierNames = await _supplierNameMap();
    return _mapRow(row, categoryNames, companyNames, supplierNames);
  }

  @override
  Future<MedicineEntity?> getById(int id) async {
    final row = await dataSource.getById(id);
    if (row == null) return null;
    final categoryNames = await _categoryNameMap();
    final companyNames = await _companyNameMap();
    final supplierNames = await _supplierNameMap();
    return _mapRow(row, categoryNames, companyNames, supplierNames);
  }

  @override
  Future<MedicineEntity> create({
    required String nameAr,
    String? nameEn,
    String? nameScientific,
    int? categoryId,
    int? companyId,
    int? supplierId,
    required String unit,
    required double purchasePrice,
    required double sellingPrice,
    int? qtyPerPack,
    int? qtyPerStrip,
    int? qtyPerCarton,
    required int reorderLevel,
    double? stripPurchasePrice,
    double? stripSellingPrice,
    double? packPurchasePrice,
    double? packSellingPrice,
    double? cartonPurchasePrice,
    double? cartonSellingPrice,
    String? barcode,
    String? reserveField1,
    String? reserveField2,
    String? reserveField3,
    int? medicineType,
  }) async {
    final barcodeValue = (barcode != null && barcode.trim().isNotEmpty)
        ? barcode.trim()
        : BarcodeGenerator.generate(companyId: companyId, categoryId: categoryId);

    final row = await dataSource.create(
      MedicinesCompanion.insert(
        nameAr: nameAr.trim(),
        nameEn: Value(nameEn?.trim()),
        nameScientific: Value(nameScientific?.trim()),
        categoryId: Value(categoryId),
        companyId: Value(companyId),
        supplierId: Value(supplierId),
        sku: barcodeValue,
        barcode: barcodeValue,
        unit: Value(unit),
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        qtyPerPack: Value(qtyPerPack),
        qtyPerStrip: Value(qtyPerStrip),
        qtyPerCarton: Value(qtyPerCarton),
        packPurchasePrice: Value(packPurchasePrice),
        packSellingPrice: Value(packSellingPrice),
        stripPurchasePrice: Value(stripPurchasePrice),
        stripSellingPrice: Value(stripSellingPrice),
        cartonPurchasePrice: Value(cartonPurchasePrice),
        cartonSellingPrice: Value(cartonSellingPrice),
        reorderLevel: Value(reorderLevel),
        reserveField1: Value(reserveField1),
        reserveField2: Value(reserveField2),
        reserveField3: Value(reserveField3),
        medicineType: Value(medicineType ?? 0),
      ),
    );

    final categoryNames = await _categoryNameMap();
    final companyNames = await _companyNameMap();
    final supplierNames = await _supplierNameMap();
    return _mapRow(row, categoryNames, companyNames, supplierNames);
  }

  @override
  Future<void> update(MedicineEntity medicine, {int? changedByUserId}) async {
    // نجلب السعر القديم قبل الكتابة فوقه - لازم لسجل تدقيق تغييرات الأسعار.
    final oldRow = await dataSource.getById(medicine.id);

    await dataSource.update(
      medicine.id,
      MedicinesCompanion(
        nameAr: Value(medicine.nameAr),
        nameEn: Value(medicine.nameEn),
        nameScientific: Value(medicine.nameScientific),
        categoryId: Value(medicine.categoryId),
        companyId: Value(medicine.companyId),
        supplierId: Value(medicine.supplierId),
        unit: Value(medicine.unit),
        purchasePrice: Value(medicine.purchasePrice),
        sellingPrice: Value(medicine.sellingPrice),
        qtyPerPack: Value(medicine.qtyPerPack),
        qtyPerStrip: Value(medicine.qtyPerStrip),
        qtyPerCarton: Value(medicine.qtyPerCarton),
        packPurchasePrice: Value(medicine.packPurchasePrice),
        packSellingPrice: Value(medicine.packSellingPrice),
        stripPurchasePrice: Value(medicine.stripPurchasePrice),
        stripSellingPrice: Value(medicine.stripSellingPrice),
        cartonPurchasePrice: Value(medicine.cartonPurchasePrice),
        cartonSellingPrice: Value(medicine.cartonSellingPrice),
        reorderLevel: Value(medicine.reorderLevel),
        barcode: Value(medicine.barcode),
        reserveField1: Value(medicine.reserveField1),
        reserveField2: Value(medicine.reserveField2),
        reserveField3: Value(medicine.reserveField3),
        medicineType: Value(medicine.medicineType),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (oldRow != null && oldRow.sellingPrice != medicine.sellingPrice) {
      await auditLogger.log(
        actionType: 'MEDICINE_PRICE_CHANGED',
        tableName: 'medicines',
        recordId: medicine.id.toString(),
        oldValue: oldRow.sellingPrice.toString(),
        newValue: medicine.sellingPrice.toString(),
        userId: changedByUserId,
      );
    }
  }

  @override
  Future<bool> updateBarcode(int medicineId, String newBarcode, {bool forceOverride = false}) async {
    try {
      await dataSource.updateBarcode(medicineId, newBarcode, forceOverride: forceOverride);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> archive(int id, {int? changedByUserId}) async {
    await dataSource.archive(id);
  }

  @override
  Future<void> writeOff(int id, double quantity, String reason, String? notes) async {}

  @override
  Future<List<MedicineEntity>> getAlternatives(int medicineId, String scientificName) async {
    final rows = await dataSource.getAlternatives(medicineId, scientificName);
    final categoryNames = await _categoryNameMap();
    final companyNames = await _companyNameMap();
    final supplierNames = await _supplierNameMap();
    return rows.map((r) => _mapRow(r, categoryNames, companyNames, supplierNames)).toList();
  }

  @override
  Future<int> autoCleanDuplicates() async {
    return dataSource.autoCleanDuplicates();
  }
}
