class SupplierBalance {
  final int supplierId;
  final String supplierName;
  final double totalPurchased;
  final double totalPaid;

  const SupplierBalance({
    required this.supplierId,
    required this.supplierName,
    required this.totalPurchased,
    required this.totalPaid,
  });

  double get remainingDebt => totalPurchased - totalPaid;
}

class VendorPaymentEntity {
  final int id;
  final int supplierId;
  final String supplierName;
  final double amount;
  final String? notes;
  final DateTime createdAt;

  const VendorPaymentEntity({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.amount,
    this.notes,
    required this.createdAt,
  });
}

class UnpaidPurchaseInvoice {
  final int id;
  final int supplierId;
  final String supplierName;
  final double totalAmount;
  final double paidAmount;
  final DateTime date;

  const UnpaidPurchaseInvoice({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.totalAmount,
    required this.paidAmount,
    required this.date,
  });

  double get remaining => totalAmount - paidAmount;
}
