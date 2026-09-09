import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../accounting/domain/repositories/general_ledger_repository.dart';
import '../../../accounting/domain/entities/accounting_entities.dart';

class CustomerCreditTotals {
  final int customerId;
  final double totalCredit;
  const CustomerCreditTotals({required this.customerId, required this.totalCredit});
}

abstract class CustomersDataSource {
  Future<List<CustomerRow>> getAll();
  Future<CustomerRow> create({required String name, String? phone, String? notes});
  Future<List<CustomerCreditTotals>> getCreditTotalsPerCustomer();
  Future<Map<int, double>> getPaymentTotalsPerCustomer();
  Future<void> recordPayment({
    required int customerId,
    required double amount,
    String? notes,
    int? recordedBy,
  });
  Future<List<TransactionRawData>> getCustomerTransactions(int customerId);
  Future<CustomerRow?> getCustomer(int id);
}

class TransactionRawData {
  final DateTime date;
  final String description;
  final double amount;
  final String type;
  final String details;
  const TransactionRawData({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.details,
  });
}

class CustomersDataSourceImpl implements CustomersDataSource {
  final AppDatabase _db;
  final GeneralLedgerRepository _glRepo;
  CustomersDataSourceImpl(this._db, this._glRepo);

  @override
  Future<List<CustomerRow>> getAll() {
    return (_db.select(_db.customers)..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
  }

  @override
  Future<CustomerRow> create({required String name, String? phone, String? notes}) async {
    final id = await _db.into(_db.customers).insert(
          CustomersCompanion.insert(name: name.trim(), phone: Value(phone), notes: Value(notes)),
        );
    return (_db.select(_db.customers)..where((c) => c.id.equals(id))).getSingle();
  }

  @override
  Future<List<CustomerCreditTotals>> getCreditTotalsPerCustomer() async {
    // فقط المبيعات الآجلة (paymentMethod = 'آجل') تُحتسب كدين على العميل
    final rows = await _db.customSelect(
      "SELECT customer_id, SUM(total_amount) AS total_credit FROM sales "
      "WHERE payment_method = 'آجل' AND customer_id IS NOT NULL "
      "GROUP BY customer_id",
      readsFrom: {_db.sales},
    ).get();

    return rows
        .map((row) => CustomerCreditTotals(
              customerId: row.read<int>('customer_id'),
              totalCredit: row.read<double>('total_credit'),
            ))
        .toList();
  }

  @override
  Future<Map<int, double>> getPaymentTotalsPerCustomer() async {
    final rows = await _db.customSelect(
      'SELECT customer_id, SUM(amount) AS total_paid FROM customer_payments GROUP BY customer_id',
      readsFrom: {_db.customerPayments},
    ).get();

    return {for (final row in rows) row.read<int>('customer_id'): row.read<double>('total_paid')};
  }

  @override
  Future<void> recordPayment({
    required int customerId,
    required double amount,
    String? notes,
    int? recordedBy,
  }) async {
    if (amount <= 0) {
      throw Exception('لا يمكن تسديد مبلغ سالب أو صفر');
    }

    return _db.transaction(() async {
      final paymentId = await _db.into(_db.customerPayments).insert(
            CustomerPaymentsCompanion.insert(
              customerId: customerId,
              amount: amount,
              notes: Value(notes),
              recordedBy: Value(recordedBy),
            ),
          );

      final cashAccId = await _glRepo.getAccountIdByCode('1101');
      final arAccId = await _glRepo.getAccountIdByCode('1103');
      
      if (cashAccId != null && arAccId != null) {
        await _glRepo.postJournalEntry(
          referenceNumber: 'C-PAY-$paymentId',
          date: DateTime.now(),
          description: 'تسديد دفعة من العميل $customerId',
          source: 'CustomerPayment',
          sourceId: paymentId,
          createdBy: recordedBy ?? 1,
          lines: [
            JournalEntryLineEntity(
              id: 0, journalEntryId: 0, accountId: cashAccId, accountName: '',
              debit: amount, credit: 0, description: 'قبض نقدية للصندوق',
            ),
            JournalEntryLineEntity(
              id: 0, journalEntryId: 0, accountId: arAccId, accountName: '',
              debit: 0, credit: amount, description: 'تخفيض مديونية العميل',
            ),
          ],
        );
      }
    });
  }

  @override
  Future<CustomerRow?> getCustomer(int id) async {
    return (_db.select(_db.customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<TransactionRawData>> getCustomerTransactions(int customerId) async {
    final transactions = <TransactionRawData>[];

    // 1. مبيعات آجلة (Sales)
    final salesQuery = _db.select(_db.sales).join([
      leftOuterJoin(_db.saleItems, _db.saleItems.saleId.equalsExp(_db.sales.id)),
      leftOuterJoin(_db.medicines, _db.medicines.id.equalsExp(_db.saleItems.medicineId)),
    ])..where(_db.sales.customerId.equals(customerId));

    final salesRows = await salesQuery.get();
    
    // Group items by sale
    final Map<int, List<String>> saleItemsMap = {};
    final Map<int, SaleRow> saleInfoMap = {};
    
    for (var row in salesRows) {
      final sale = row.readTable(_db.sales);
      saleInfoMap[sale.id] = sale;
      
      final medicine = row.readTableOrNull(_db.medicines);
      final item = row.readTableOrNull(_db.saleItems);
      if (medicine != null && item != null) {
        saleItemsMap.putIfAbsent(sale.id, () => []).add('${medicine.nameAr} (${item.quantity})');
      }
    }

    for (var sale in saleInfoMap.values) {
      // فقط المبيعات الآجلة تُعتبر دين على العميل
      if (sale.paymentMethod == 'آجل') {
        transactions.add(TransactionRawData(
          date: sale.createdAt,
          description: 'فاتورة مبيعات #${sale.invoiceNumber}',
          amount: sale.totalAmount,
          type: 'SALE',
          details: saleItemsMap[sale.id]?.join('، ') ?? 'بدون تفاصيل',
        ));
      }
    }

    // 2. دفعات العميل (Payments)
    final payments = await (_db.select(_db.customerPayments)..where((p) => p.customerId.equals(customerId))).get();
    for (var p in payments) {
      transactions.add(TransactionRawData(
        date: p.createdAt,
        description: 'دفعة تسديد',
        amount: p.amount,
        type: 'PAYMENT',
        details: p.notes ?? 'لا يوجد ملاحظات',
      ));
    }

    // Sort by date (oldest to newest for statement)
    transactions.sort((a, b) => a.date.compareTo(b.date));
    return transactions;
  }
}
