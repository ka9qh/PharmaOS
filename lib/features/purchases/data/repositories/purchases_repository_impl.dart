
import '../../domain/entities/purchases_entity.dart';
import '../../domain/repositories/purchases_repository.dart';
import '../datasources/purchases_datasource.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/audit_logger.dart';
import '../../../suppliers/domain/repositories/suppliers_repository.dart';

class PurchasesRepositoryImpl implements PurchasesRepository {
  @override
  Future<void> addPaymentToPurchase({required int purchaseId, required double amount, required String paymentMethod, int? walletId}) async {}


  
  final PurchasesDataSource dataSource;
  final SuppliersRepository suppliersRepository;
  final AuditLogger auditLogger;

  PurchasesRepositoryImpl({
    required this.dataSource,
    required this.suppliersRepository,
    required this.auditLogger,
  });

  Future<PurchaseEntity> _mapRow(PurchaseRow row) async {
    final suppliers = await suppliersRepository.getAll();
    final matches = suppliers.where((s) => s.id == row.supplierId).toList();
    final supplierName = matches.isNotEmpty ? matches.first.name : 'مورد غير معروف';

    return PurchaseEntity(
      id: row.id,
      purchaseNumber: row.purchaseNumber,
      supplierInvoiceRef: row.supplierInvoiceRef,
      supplierId: row.supplierId,
      supplierName: supplierName,
      totalAmount: row.totalAmount,
      paidAmount: row.paidAmount,
      invoiceImagePath: row.invoiceImagePath,
      createdAt: row.createdAt,
    );
  }

  @override
  Future<PurchaseEntity> createPurchase({
    required int supplierId,
    String? supplierInvoiceRef,
    required List<PurchaseLineInput> items,
    required double paidAmount,
    String? invoiceImagePath,
  }) async {
    final row = await dataSource.createPurchaseTransactional(
      supplierId: supplierId,
      supplierInvoiceRef: supplierInvoiceRef,
      items: items
          .map((i) => (
                medicineId: i.medicineId,
                quantity: i.quantity,
                unitCost: i.unitCost,
                sellingPrice: i.sellingPrice,
                batchNumber: i.batchNumber,
                expiryDate: i.expiryDate,
                qtyCarton: i.qtyCarton ?? 0,
                qtyPack: i.qtyPack ?? 0,
                qtyStrip: i.qtyStrip ?? 0,
                qtyPill: i.qtyPill ?? 0,
              ))
          .toList(),
      paidAmount: paidAmount,
      invoiceImagePath: invoiceImagePath,
    );

    await auditLogger.log(
      actionType: 'PURCHASE_CREATED',
      tableName: 'purchases',
      recordId: row.id.toString(),
      newValue: 'purchase=${row.purchaseNumber}, total=${row.totalAmount}',
    );

    return _mapRow(row);
  }

  @override
  Future<List<PurchaseEntity>> listRecent({int limit = 50}) async {
    final rows = await dataSource.listRecent(limit: limit);
    final entities = <PurchaseEntity>[];
    for (final row in rows) {
      entities.add(await _mapRow(row));
    }
    return entities;
  }

  
}

