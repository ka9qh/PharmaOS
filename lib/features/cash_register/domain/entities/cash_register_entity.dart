class WalletEntity {
  final int id;
  final String name;
  final double balance; // Calculated dynamically from transactions

  const WalletEntity({
    required this.id,
    required this.name,
    this.balance = 0.0,
  });
}

class TransactionEntity {
  final int id;
  final String description;
  final double amount;
  final DateTime date;
  final String type; // 'IN' or 'OUT'
  final String source; // e.g. 'sale', 'expense', 'vendor_payment'

  const TransactionEntity({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.source,
  });
}
