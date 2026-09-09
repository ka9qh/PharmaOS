import '../../domain/entities/accounting_entity.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../datasources/accounting_datasource.dart';
import '../../../suppliers/domain/repositories/suppliers_repository.dart';

class AccountingRepositoryImpl implements AccountingRepository {
  final AccountingDataSource dataSource;
  final SuppliersRepository suppliersRepository;

  AccountingRepositoryImpl({
    required this.dataSource,
    required this.suppliersRepository,
  });

  @override
  Future<List<SupplierBalance>> getSupplierBalances() async {
    final purchaseTotals = await dataSource.getPurchaseTotalsPerSupplier();
    final vendorPaymentTotals = await dataSource.getVendorPaymentTotalsPerSupplier();
    final suppliers = await suppliersRepository.getAll();
    final supplierNames = {for (final s in suppliers) s.id: s.name};

    return purchaseTotals.map((p) {
      final paidAtPurchase = p.totalPaidAtPurchase;
      final laterPayments = vendorPaymentTotals[p.supplierId] ?? 0;
      return SupplierBalance(
        supplierId: p.supplierId,
        supplierName: supplierNames[p.supplierId] ?? 'مورد غير معروف',
        totalPurchased: p.totalPurchased,
        totalPaid: paidAtPurchase + laterPayments,
      );
    }).toList();
  }

  @override
  Future<List<VendorPaymentEntity>> getRecentPayments({int limit = 50}) async {
    return [];
  }

  @override
  Future<List<UnpaidPurchaseInvoice>> getUnpaidPurchaseInvoices() async {
    return [];
  }

  @override
  Future<VendorPaymentEntity> recordVendorPayment({
    required int supplierId,
    required double amount,
    required String paymentMethod,
    int? walletId,
    String? notes,
    int? recordedBy,
  }) async {
    final row = await dataSource.recordVendorPayment(
      supplierId: supplierId,
      amount: amount,
      
      
      notes: notes,
      recordedBy: recordedBy,
    );

    final suppliers = await suppliersRepository.getAll();
    final matches = suppliers.where((s) => s.id == supplierId).toList();
    final supplierName = matches.isNotEmpty ? matches.first.name : 'مورد غير معروف';

    return VendorPaymentEntity(
      id: row.id,
      supplierId: row.supplierId,
      supplierName: supplierName,
      amount: row.amount,
      notes: row.notes,
      createdAt: row.createdAt,
    );
  }
}
