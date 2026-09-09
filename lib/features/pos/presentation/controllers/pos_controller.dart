class PosController {
  PosController._();

  static String? validateDiscount(String text, double subtotal) {
    if (text.trim().isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value < 0) return 'قيمة خصم غير صالحة';
    if (value > subtotal) return 'الخصم أكبر من إجمالي الفاتورة';
    return null;
  }
}
