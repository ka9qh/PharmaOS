// ظ…ط¯ط®ظ„ ط³ط·ط± ظˆط§ط­ط¯ ظپظٹ ط§ظ„ط³ظ„ط© ط¹ظ†ط¯ ط¥ط±ط³ط§ظ„ظ‡ ظ„ط¥طھظ…ط§ظ… ط¹ظ…ظ„ظٹط© ط§ظ„ط¨ظٹط¹ (Domain Input - ظ…ط³طھظ‚ظ„ ط¹ظ† UI)
class CartLineInput {
  final int medicineId;
  final String medicineName;
  final int quantity; // quantityInBase
  final double unitPrice;
  final String unitName;
  final int conversionFactor;
  final int selectedQuantity;
  final DateTime? expiryDate;
  final int? batchId;

  const CartLineInput({
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitPrice,
    required this.unitName,
    required this.conversionFactor,
    required this.selectedQuantity,
    this.expiryDate,
    this.batchId,
  });
}

class SaleEntity {
  final int id;
  final String invoiceNumber;
  final int? customerId;
  final double totalAmount;
  final double discount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;

  const SaleEntity({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.totalAmount,
    required this.discount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });
}
