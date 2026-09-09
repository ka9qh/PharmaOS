class MedicineFormValidationResult {
  final bool isValid;
  final String? nameError;
  final String? purchasePriceError;
  final String? sellingPriceError;
  final String? reorderLevelError;

  const MedicineFormValidationResult({
    required this.isValid,
    this.nameError,
    this.purchasePriceError,
    this.sellingPriceError,
    this.reorderLevelError,
  });
}

class MedicinesController {
  MedicinesController._();

  static MedicineFormValidationResult validate({
    required String nameAr,
    required String purchasePriceText,
    required String sellingPriceText,
    required String reorderLevelText,
  }) {
    String? nameError;
    String? purchasePriceError;
    String? sellingPriceError;
    String? reorderLevelError;

    if (nameAr.trim().isEmpty) {
      nameError = 'الرجاء إدخال اسم الدواء';
    }

    final purchasePrice = double.tryParse(purchasePriceText);
    if (purchasePrice == null || purchasePrice < 0) {
      purchasePriceError = 'سعر شراء غير صالح';
    }

    final sellingPrice = double.tryParse(sellingPriceText);
    if (sellingPrice == null || sellingPrice <= 0) {
      sellingPriceError = 'سعر بيع غير صالح';
    }

    final reorderLevel = int.tryParse(reorderLevelText);
    if (reorderLevel == null || reorderLevel < 0) {
      reorderLevelError = 'رقم غير صالح';
    }

    return MedicineFormValidationResult(
      isValid: nameError == null &&
          purchasePriceError == null &&
          sellingPriceError == null &&
          reorderLevelError == null,
      nameError: nameError,
      purchasePriceError: purchasePriceError,
      sellingPriceError: sellingPriceError,
      reorderLevelError: reorderLevelError,
    );
  }
}
