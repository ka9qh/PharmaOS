import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class SupplierPurchaseTotals {
  final int supplierId;
  final double totalPurchased;
  final double totalPaidAtPurchase;
  const SupplierPurchaseTotals({
    required this.supplierId,
    required this.totalPurchased,
    required this.totalPaidAtPurchase,
  });
}

abstract class AccountingDataSource {
  Future<List<SupplierPurchaseTotals>> getPurchaseTotalsPerSupplier();
  Future<Map<int, double>> getVendorPaymentTotalsPerSupplier();
  Future<VendorPaymentRow> recordVendorPayment({
    required int supplierId,
    required double amount,
    String? notes,
    int? recordedBy,
  });
}

class AccountingDataSourceImpl implements AccountingDataSource {
  final AppDatabase _db;
  AccountingDataSourceImpl(this._db);

  @override
  Future<List<SupplierPurchaseTotals>> getPurchaseTotalsPerSupplier() async {
    final rows = await _db.customSelect(
      'SELECT supplier_id, SUM(total_amount) AS total_purchased, '
      'SUM(paid_amount) AS total_paid_at_purchase '
      'FROM purchases GROUP BY supplier_id',
      readsFrom: {_db.purchases},
    ).get();

    return rows
        .map((row) => SupplierPurchaseTotals(
              supplierId: row.read<int>('supplier_id'),
              totalPurchased: row.read<double>('total_purchased'),
              totalPaidAtPurchase: row.read<double>('total_paid_at_purchase'),
            ))
        .toList();
  }

  @override
  Future<Map<int, double>> getVendorPaymentTotalsPerSupplier() async {
    final rows = await _db.customSelect(
      'SELECT supplier_id, SUM(amount) AS total_paid '
      'FROM vendor_payments GROUP BY supplier_id',
      readsFrom: {_db.vendorPayments},
    ).get();

    return {
      for (final row in rows) row.read<int>('supplier_id'): row.read<double>('total_paid'),
    };
  }

  @override
  Future<VendorPaymentRow> recordVendorPayment({
    required int supplierId,
    required double amount,
    String? notes,
    int? recordedBy,
  }) async {
    final id = await _db.into(_db.vendorPayments).insert(
          VendorPaymentsCompanion.insert(
            supplierId: supplierId,
            amount: amount,
            notes: Value(notes),
            recordedBy: Value(recordedBy),
          ),
        );
    return (_db.select(_db.vendorPayments)..where((v) => v.id.equals(id))).getSingle();
  }
}
