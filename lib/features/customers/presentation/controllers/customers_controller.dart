class CustomersController {
  CustomersController._();

  static String? validateName(String name) {
    if (name.trim().isEmpty) return 'الرجاء إدخال اسم العميل';
    if (name.trim().length > 150) return 'الاسم طويل جدًا';
    return null;
  }

  static String? validatePaymentAmount(String text, double remainingDebt) {
    final value = double.tryParse(text);
    if (value == null || value <= 0) return 'مبلغ غير صالح';
    if (value > remainingDebt) return 'المبلغ أكبر من المتبقي على هذا العميل';
    return null;
  }
}
