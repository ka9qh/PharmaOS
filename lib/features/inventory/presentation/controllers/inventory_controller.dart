class ReceiveStockValidationResult {
  final bool isValid;
  final String? medicineError;
  final String? quantityError;
  final String? purchasePriceError;

  const ReceiveStockValidationResult({
    required this.isValid,
    this.medicineError,
    this.quantityError,
    this.purchasePriceError,
  });
}

class InventoryController {
  InventoryController._();

  static ReceiveStockValidationResult validate({
    required int? medicineId,
    required String quantityText,
    required String purchasePriceText,
  }) {
    final medicineError = medicineId == null ? 'الرجاء اختيار الدواء' : null;

    final quantity = int.tryParse(quantityText);
    final quantityError =
        (quantity == null || quantity <= 0) ? 'كمية غير صالحة' : null;

    final purchasePrice = double.tryParse(purchasePriceText);
    final purchasePriceError =
        (purchasePrice == null || purchasePrice < 0) ? 'سعر شراء غير صالح' : null;

    return ReceiveStockValidationResult(
      isValid: medicineError == null && quantityError == null && purchasePriceError == null,
      medicineError: medicineError,
      quantityError: quantityError,
      purchasePriceError: purchasePriceError,
    );
  }
}
