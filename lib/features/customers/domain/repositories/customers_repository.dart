
import '../entities/customers_entity.dart';
import '../entities/customer_statement_entity.dart';

abstract class CustomersRepository {
  Future<List<CustomerEntity>> getAll();

  Future<CustomerEntity> create({
    required String name,
    String? phone,
    String? notes,
  });

  /// أرصدة كل العملاء الذين عليهم مبيعات آجلة - محسوبة من السجل مباشرة
  /// (مبيعات آجلة - تسديدات) وليست عمودًا مخزَّنًا، بنفس مبدأ AccountingRepository.
  Future<List<CustomerBalance>> getCustomerBalances();

  Future<void> recordPayment({
    required int customerId,
    required double amount,
    String? notes,
    int? recordedBy,
  });

  /// كشف حساب العميل مفصل (فواتيره، مشترياته بالتفصيل، والدفعات)
  Future<CustomerStatementEntity> getCustomerStatement(int customerId);
  Future<List<CustomerTransactionEntity>> getCustomerTransactions(int customerId);
  Future<void> update(int id, String newName, String? newPhone, String? newNotes);
  Future<void> archive(int id);
}

