class ExpiryAlertEntity {
  final int batchId;
  final int medicineId;
  final String medicineName;
  final String batchNumber;
  final int quantity;
  final DateTime expiryDate;

  const ExpiryAlertEntity({
    required this.batchId,
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.quantity,
    required this.expiryDate,
  });

  /// 0 = Expired (أحمر)
  /// 1 = Expiring in < 3 months (برتقالي)
  /// 2 = Expiring in < 6 months (أصفر)
  int get expiryStatus {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    
    if (difference <= 0) return 0;
    if (difference <= 90) return 1;
    return 2;
  }
}
