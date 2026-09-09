import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/entities/ledger_entry_entity.dart';

class SupplierLedgerDataSource {
  final AppDatabase _db;

  SupplierLedgerDataSource(this._db);

  Future<List<LedgerEntryEntity>> getSupplierLedger(int supplierId, {DateTime? startDate, DateTime? endDate}) async {
    final List<LedgerEntryEntity> entries = [];

    // 1. فواتير المشتريات (دائن / له) + الدفعات المسددة فورياً عند الشراء (مدين / عليه)
    var purchasesQuery = _db.select(_db.purchases)
      ..where((t) => t.supplierId.equals(supplierId));
      
    if (startDate != null) purchasesQuery.where((t) => t.createdAt.isBiggerOrEqualValue(startDate));
    if (endDate != null) purchasesQuery.where((t) => t.createdAt.isSmallerOrEqualValue(endDate));

    final purchases = await purchasesQuery.get();
    for (final p in purchases) {
      // قيد الفاتورة الإجمالي
      entries.add(LedgerEntryEntity(
        date: p.createdAt,
        description: 'فاتورة مشتريات #${p.purchaseNumber} (مرجع: ${p.supplierInvoiceRef ?? "بدون"})',
        referenceNumber: p.purchaseNumber,
        debit: 0.0,
        credit: p.totalAmount, // دائن (له)
        balance: 0.0,
      ));

      // إذا تم دفع دفعة نقدية فورية عند الشراء
      if (p.paidAmount > 0) {
        entries.add(LedgerEntryEntity(
          date: p.createdAt.add(const Duration(seconds: 1)),
          description: 'سداد فوري لفاتورة #${p.purchaseNumber} (${p.paymentMethod ?? "نقدي"})',
          referenceNumber: 'PAY-${p.purchaseNumber}',
          debit: p.paidAmount, // مدين (عليه)
          credit: 0.0,
          balance: 0.0,
        ));
      }
    }

    // 2. سندات السداد والدفع المستقلة (مدين / عليه)
    var paymentsQuery = _db.select(_db.vendorPayments)
      ..where((t) => t.supplierId.equals(supplierId));

    if (startDate != null) paymentsQuery.where((t) => t.createdAt.isBiggerOrEqualValue(startDate));
    if (endDate != null) paymentsQuery.where((t) => t.createdAt.isSmallerOrEqualValue(endDate));

    final payments = await paymentsQuery.get();
    for (final pay in payments) {
      entries.add(LedgerEntryEntity(
        date: pay.createdAt,
        description: pay.notes != null && pay.notes!.isNotEmpty
            ? 'سند سداد مورد: ${pay.notes}'
            : 'سند سداد دفعة مورد (${pay.paymentMethod})',
        referenceNumber: 'V-PAY-${pay.id}',
        debit: pay.amount, // مدين (عليه)
        credit: 0.0,
        balance: 0.0,
      ));
    }

    // 3. مرتجعات المشتريات من جدول returns (مدين / عليه)
    final allVendorReturns = await (_db.select(_db.returns).join([
      innerJoin(_db.purchases, _db.purchases.id.equalsExp(_db.returns.purchaseId)),
    ])..where(_db.purchases.supplierId.equals(supplierId))).get();

    for (final row in allVendorReturns) {
      final r = row.readTable(_db.returns);
      final p = row.readTable(_db.purchases);
      if (startDate != null && r.createdAt.isBefore(startDate)) continue;
      if (endDate != null && r.createdAt.isAfter(endDate)) continue;

      entries.add(LedgerEntryEntity(
        date: r.createdAt,
        description: 'فاتورة مرتجع مشتريات (أصل: ${p.purchaseNumber}) - ${r.reason ?? "مرتجع بضاعة"}',
        referenceNumber: 'RET-V-${r.id}',
        debit: r.totalAmount, // مدين (عليه)
        credit: 0.0,
        balance: 0.0,
      ));
    }

    // 4. مرتجعات المشتريات من جدول purchaseReturns إن وُجدت
    var legacyReturnsQuery = _db.select(_db.purchaseReturns)
      ..where((t) => t.supplierId.equals(supplierId));
      
    if (startDate != null) legacyReturnsQuery.where((t) => t.createdAt.isBiggerOrEqualValue(startDate));
    if (endDate != null) legacyReturnsQuery.where((t) => t.createdAt.isSmallerOrEqualValue(endDate));

    final legacyReturns = await legacyReturnsQuery.get();
    for (final r in legacyReturns) {
      entries.add(LedgerEntryEntity(
        date: r.createdAt,
        description: 'فاتورة مرتجع مورد',
        referenceNumber: r.referenceNumber,
        debit: r.totalAmount, // مدين (عليه)
        credit: 0.0,
        balance: 0.0,
      ));
    }

    // الترتيب الزمني
    entries.sort((a, b) => a.date.compareTo(b.date));

    // حساب الرصيد التراكمي: الرصيد = (الرصيد السابق) + دائن (له) - مدين (عليه)
    double currentBalance = 0.0;
    List<LedgerEntryEntity> calculatedEntries = [];
    
    for (final entry in entries) {
      currentBalance += entry.credit - entry.debit;
      calculatedEntries.add(entry.copyWith(balance: currentBalance));
    }

    return calculatedEntries;
  }
}
