import '../../domain/entities/suppliers_entity.dart';
import '../../domain/repositories/suppliers_repository.dart';
import '../datasources/suppliers_datasource.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/audit_logger.dart';
import '../../../purchases/domain/entities/purchases_entity.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';

class SuppliersRepositoryImpl implements SuppliersRepository {
  @override
  Future<List<dynamic>> getPharmacyDebts() async { return []; }
  final SuppliersDataSource dataSource;
  SuppliersRepositoryImpl(this.dataSource);

  @override
  Future<List<SupplierEntity>> getAll() async {
    final rows = await dataSource.getAll();
    return rows.map((r) => SupplierEntity(
      id: r.id,
      name: r.name,
      contactInfo: r.contactInfo,
      notes: r.notes,
    )).toList();
  }

  @override
  Future<SupplierEntity> create({
    required String name,
    String? contactInfo,
    String? notes,
  }) async {
    final row = await dataSource.create(name: name, contactInfo: contactInfo, notes: notes);
    return SupplierEntity(
      id: row.id,
      name: row.name,
      contactInfo: row.contactInfo,
      notes: row.notes,
    );
  }

  @override
  Future<void> update(int id, String newName) {
    return dataSource.update(id, newName);
  }

  @override
  Future<void> archive(int id) {
    return dataSource.archive(id);
  }

  @override
  Future<void> recordVendorPayment({
    required int supplierId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) {
    return dataSource.recordVendorPayment(
      supplierId: supplierId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }

  @override
  Future<List<PurchaseEntity>> getSupplierPurchases(int supplierId) async {
    final rows = await dataSource.getSupplierPurchases(supplierId);
    // Map them. We need supplierName, but we know the supplierId.
    // For simplicity in this list, we can just use an empty string or fetch the supplier name once.
    final suppliers = await getAll();
    final supplierName = suppliers.firstWhere((s) => s.id == supplierId, orElse: () => const SupplierEntity(id: 0, name: 'مورد غير معروف')).name;
    
    return rows.map((r) => PurchaseEntity(
      id: r.id,
      purchaseNumber: r.purchaseNumber,
      supplierInvoiceRef: r.supplierInvoiceRef,
      supplierId: r.supplierId,
      supplierName: supplierName,
      totalAmount: r.totalAmount,
      paidAmount: r.paidAmount,
      invoiceImagePath: r.invoiceImagePath,
      createdAt: r.createdAt,
    )).toList();
  }

  @override
  Future<List<MedicineEntity>> getSupplierMedicines(int supplierId) async {
    final rows = await dataSource.getSupplierMedicines(supplierId);
    return rows.map((r) => MedicineEntity(
      id: r.id,
      nameAr: r.nameAr,
      nameEn: r.nameEn,
      nameScientific: r.nameScientific,
      categoryId: r.categoryId,
      companyId: r.companyId,
      supplierId: r.supplierId,
      sku: r.sku,
      barcode: r.barcode,
      unit: r.unit,
      purchasePrice: r.purchasePrice,
      sellingPrice: r.sellingPrice,
      reorderLevel: r.reorderLevel,
      isActive: r.isActive,
      medicineType: r.medicineType,
      qtyPerPack: r.qtyPerPack,
      qtyPerStrip: r.qtyPerStrip,
      qtyPerCarton: r.qtyPerCarton,
      packPurchasePrice: r.packPurchasePrice,
      packSellingPrice: r.packSellingPrice,
      stripPurchasePrice: r.stripPurchasePrice,
      stripSellingPrice: r.stripSellingPrice,
      cartonPurchasePrice: r.cartonPurchasePrice,
      cartonSellingPrice: r.cartonSellingPrice,
    )).toList();
  }
}
