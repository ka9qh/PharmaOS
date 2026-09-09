// سطر واحد في سلة نقطة البيع - حالة مؤقتة (In-Memory) فقط، لا تُحفظ في قاعدة
// البيانات إلا عند إتمام البيع فعليًا (عندها تتحول إلى CartLineInput في ميزة sales).

class CartItem {
  final int medicineId;
  final String medicineName;
  final double unitPrice; // السعر الدقيق للوحدة المحددة (حبة، شريط، باكت)
  final int availableStockInBase;
  
  final String selectedUnitName;
  final int selectedUnitMultiplier;
  final int selectedQuantity;
  final String? batchNumber;
  final DateTime? expiryDate;
  final int? batchId;

  const CartItem({
    required this.medicineId,
    required this.medicineName,
    required this.unitPrice,
    required this.availableStockInBase,
    required this.selectedUnitName,
    required this.selectedUnitMultiplier,
    required this.selectedQuantity,
    this.batchNumber,
    this.expiryDate,
    this.batchId,
  });

  double get subtotal => unitPrice * selectedQuantity;
  int get quantityInBase => selectedQuantity * selectedUnitMultiplier;

  CartItem copyWith({
    int? selectedQuantity,
    double? unitPrice,
    String? selectedUnitName,
    int? selectedUnitMultiplier,
    String? batchNumber,
    DateTime? expiryDate,
    int? batchId,
  }) {
    return CartItem(
      medicineId: medicineId,
      medicineName: medicineName,
      unitPrice: unitPrice ?? this.unitPrice,
      availableStockInBase: availableStockInBase,
      selectedUnitName: selectedUnitName ?? this.selectedUnitName,
      selectedUnitMultiplier: selectedUnitMultiplier ?? this.selectedUnitMultiplier,
      selectedQuantity: selectedQuantity ?? this.selectedQuantity,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      batchId: batchId ?? this.batchId,
    );
  }
}
