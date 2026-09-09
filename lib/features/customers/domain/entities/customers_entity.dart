class CustomerEntity {
  final int id;
  final String name;
  final String? phone;
  final String? notes;

  const CustomerEntity({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
  });
}

class CustomerBalance {
  final int customerId;
  final String customerName;
  final double totalCredit;
  final double totalPaid;

  const CustomerBalance({
    required this.customerId,
    required this.customerName,
    required this.totalCredit,
    required this.totalPaid,
  });

  double get remainingDebt => totalCredit - totalPaid;
  double get totalInvoiced => totalCredit;
}

class CustomerTransactionEntity {
  final int id;
  final int customerId;
  final double amount;
  final String description;
  final String type;
  final DateTime date;
  const CustomerTransactionEntity({required this.id, required this.customerId, required this.amount, required this.description, required this.type, required this.date});
}
