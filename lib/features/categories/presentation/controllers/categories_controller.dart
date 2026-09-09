class CategoriesController {
  CategoriesController._();

  static String? validateName(String name) {
    if (name.trim().isEmpty) return 'الرجاء إدخال اسم التصنيف';
    if (name.trim().length > 100) return 'الاسم طويل جدًا';
    return null;
  }
}
