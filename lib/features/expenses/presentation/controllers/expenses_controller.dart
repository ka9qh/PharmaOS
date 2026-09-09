class ExpensesController {
  ExpensesController._();

  static const List<String> commonCategories = [
    'إيجار',
    'كهرباء',
    'ماء',
    'رواتب',
    'صيانة',
    'نقل',
    'أخرى',
  ];

  static String? validateCategory(String category) {
    return category.trim().isEmpty ? 'الرجاء اختيار أو إدخال التصنيف' : null;
  }

  static String? validateAmount(String text) {
    final value = double.tryParse(text);
    return (value == null || value <= 0) ? 'مبلغ غير صالح' : null;
  }
}
