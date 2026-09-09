class PurchasesController {
  PurchasesController._();

  static String? validateSupplier(int? supplierId) {
    return supplierId == null ? 'الرجاء اختيار المورد' : null;
  }

  static String? validateLineQuantity(String text) {
    final value = int.tryParse(text);
    return (value == null || value <= 0) ? 'كمية غير صالحة' : null;
  }

  static String? validateLineCost(String text) {
    final value = double.tryParse(text);
    return (value == null || value < 0) ? 'تكلفة غير صالحة' : null;
  }

  static String? validatePaidAmount(String text, double totalAmount) {
    if (text.trim().isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value < 0) return 'مبلغ غير صالح';
    if (value > totalAmount) return 'المدفوع أكبر من إجمالي الفاتورة';
    return null;
  }
}
