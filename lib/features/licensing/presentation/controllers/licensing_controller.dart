class LicensingController {
  LicensingController._();

  static String? validateLicenseKey(String text) {
    if (text.trim().isEmpty) return 'الرجاء إدخال مفتاح الترخيص';
    if (!text.contains('.')) return 'صيغة المفتاح غير صحيحة - تأكد من نسخه كاملاً';
    return null;
  }
}
