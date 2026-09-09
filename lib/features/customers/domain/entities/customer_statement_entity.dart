class CustomerStatementEntity {
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final double remainingDebt;
  final List<CustomerTransaction> transactions;

  const CustomerStatementEntity({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.remainingDebt,
    required this.transactions,
  });
}

class CustomerTransaction {
  final DateTime date;
  final String description; // e.g. "فاتورة مبيعات #1234", "تسديد نقدي"
  final double amount;
  final String type; // 'SALE' (increases debt) or 'PAYMENT' (decreases debt)
  final String details; // List of medicines for SALE, or notes for PAYMENT

  const CustomerTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.details,
  });
}
