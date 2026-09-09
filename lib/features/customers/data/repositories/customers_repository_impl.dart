import '../../domain/entities/customers_entity.dart';
import '../../domain/entities/customer_statement_entity.dart';
import '../../domain/repositories/customers_repository.dart';
import '../datasources/customers_datasource.dart';
import '../models/customers_model.dart';
import '../../../../core/security/audit_logger.dart';

class CustomersRepositoryImpl implements CustomersRepository {
  final CustomersDataSource dataSource;
  final AuditLogger auditLogger;

  CustomersRepositoryImpl({required this.dataSource, required this.auditLogger});

  @override
  Future<List<CustomerEntity>> getAll() async {
    final rows = await dataSource.getAll();
    return rows.map((r) => r.toEntity()).toList();
  }

  @override
  Future<CustomerEntity> create({required String name, String? phone, String? notes}) async {
    final row = await dataSource.create(name: name, phone: phone, notes: notes);
    await auditLogger.log(
      actionType: 'CUSTOMER_CREATED',
      tableName: 'customers',
      recordId: row.id.toString(),
      newValue: 'name=${row.name}',
    );
    return row.toEntity();
  }

  @override
  Future<List<CustomerBalance>> getCustomerBalances() async {
    final creditTotals = await dataSource.getCreditTotalsPerCustomer();
    final paymentTotals = await dataSource.getPaymentTotalsPerCustomer();
    final customers = await dataSource.getAll();
    final customerNames = {for (final c in customers) c.id: c.name};

    return creditTotals
        .map((c) => CustomerBalance(
              customerId: c.customerId,
              customerName: customerNames[c.customerId] ?? 'عميل غير معروف',
              totalCredit: c.totalCredit,
              totalPaid: paymentTotals[c.customerId] ?? 0,
            ))
        .toList();
  }

  @override
  Future<void> recordPayment({
    required int customerId,
    required double amount,
    String? notes,
    int? recordedBy,
  }) async {
    await dataSource.recordPayment(
      customerId: customerId,
      amount: amount,
      notes: notes,
      recordedBy: recordedBy,
    );
    await auditLogger.log(
      actionType: 'CUSTOMER_PAYMENT_RECORDED',
      tableName: 'customer_payments',
      recordId: customerId.toString(),
      userId: recordedBy,
      newValue: 'amount=$amount',
    );
  }

  @override
  Future<CustomerStatementEntity> getCustomerStatement(int customerId) async {
    final customer = await dataSource.getCustomer(customerId);
    if (customer == null) throw Exception('العميل غير موجود');

    final transactionsRaw = await dataSource.getCustomerTransactions(customerId);
    final transactions = transactionsRaw.map((t) => CustomerTransaction(
      date: t.date,
      description: t.description,
      amount: t.amount,
      type: t.type,
      details: t.details,
    )).toList();

    double remainingDebt = 0;
    for (var t in transactions) {
      if (t.type == 'SALE') remainingDebt += t.amount;
      else if (t.type == 'PAYMENT') remainingDebt -= t.amount;
    }

    return CustomerStatementEntity(
      customerId: customer.id,
      customerName: customer.name,
      customerPhone: customer.phone,
      remainingDebt: remainingDebt,
      transactions: transactions,
    );
  }

  @override
  Future<List<CustomerTransactionEntity>> getCustomerTransactions(int customerId) async { return []; }

  @override
  Future<void> update(int id, String newName, String? newPhone, String? newNotes) async {}

  @override
  Future<void> archive(int id) async {}
}
