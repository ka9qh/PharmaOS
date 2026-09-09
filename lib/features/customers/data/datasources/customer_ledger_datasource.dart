import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/entities/ledger_entry_entity.dart';

class CustomerLedgerDataSource {
  final AppDatabase _db;

  CustomerLedgerDataSource(this._db);

  Future<List<LedgerEntryEntity>> getCustomerLedger(int customerId, {DateTime? startDate, DateTime? endDate}) async {
    final List<LedgerEntryEntity> entries = [];

    // 1. فواتير المبيعات الآجلة (تزيد مديونية العميل)
    // نأخذ الفواتير الآجلة فقط، أو كل الفواتير المتعلقة بالعميل.
    var salesQuery = _db.select(_db.sales)
      ..where((t) => t.customerId.equals(customerId) & t.paymentMethod.equals('آجل'));
      
    if (startDate != null) salesQuery.where((t) => t.createdAt.isBiggerOrEqualValue(startDate));
    if (endDate != null) salesQuery.where((t) => t.createdAt.isSmallerOrEqualValue(endDate));

    final sales = await salesQuery.get();
    for (final s in sales) {
      entries.add(LedgerEntryEntity(
        date: s.createdAt,
        description: 'فاتورة مبيعات آجلة',
        referenceNumber: s.invoiceNumber,
        debit: s.totalAmount - s.discount, // مدين (عليه)
        credit: 0.0,
        balance: 0.0,
      ));
    }

    // 2. سندات السداد والدفع (تنقص من مديونية العميل)
    var paymentsQuery = _db.select(_db.customerPayments)
      ..where((t) => t.customerId.equals(customerId));

    if (startDate != null) paymentsQuery.where((t) => t.createdAt.isBiggerOrEqualValue(startDate));
    if (endDate != null) paymentsQuery.where((t) => t.createdAt.isSmallerOrEqualValue(endDate));

    final payments = await paymentsQuery.get();
    for (final pay in payments) {
      entries.add(LedgerEntryEntity(
        date: pay.createdAt,
        description: pay.notes ?? 'سند قبض عميل (${pay.paymentMethod})',
        referenceNumber: 'C-PAY-${pay.id}',
        debit: 0.0, 
        credit: pay.amount, // دائن (له)
        balance: 0.0,
      ));
    }

    /*
    // 3. مرتجعات العملاء الآجلة (تنقص مديونية العميل)
    // TODO: Returns table was refactored, need to join with Sales table to get customerId
    var returnsQuery = _db.select(_db.returns)
      ..where((t) => t.saleId.isNotNull());
      
    if (startDate != null) returnsQuery.where((t) => t.createdAt.isBiggerOrEqualValue(startDate));
    if (endDate != null) returnsQuery.where((t) => t.createdAt.isSmallerOrEqualValue(endDate));

    final returns = await returnsQuery.get();
    for (final r in returns) {
      entries.add(LedgerEntryEntity(
        date: r.createdAt,
        description: 'فاتورة مرتجع مبيعات',
        referenceNumber: 'RET-${r.id}',
        debit: 0.0, 
        credit: r.totalAmount, // دائن (له)
        balance: 0.0,
      ));
    }
    */

    // الترتيب الزمني
    entries.sort((a, b) => a.date.compareTo(b.date));

    // حساب الرصيد التراكمي
    // الرصيد للعميل = (الرصيد السابق) + مدين (عليه) - دائن (له)
    double currentBalance = 0.0;
    List<LedgerEntryEntity> calculatedEntries = [];
    
    for (final entry in entries) {
      currentBalance += entry.debit - entry.credit;
      calculatedEntries.add(entry.copyWith(balance: currentBalance));
    }

    return calculatedEntries;
  }
}
