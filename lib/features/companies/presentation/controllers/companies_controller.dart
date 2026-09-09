class CompaniesController {
  CompaniesController._();

  static String? validateName(String name) {
    if (name.trim().isEmpty) return 'الرجاء إدخال اسم الشركة';
    if (name.trim().length > 150) return 'الاسم طويل جدًا';
    return null;
  }
}
