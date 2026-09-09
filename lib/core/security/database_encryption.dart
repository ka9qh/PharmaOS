// إدارة مفتاح تشفير قاعدة البيانات
//
// المصدر الحالي (Phase 1): مفتاح ثابت مشتق من قيمة سرية داخل الكود.
// TODO (Phase 7 - Licensing): ربط هذا المفتاح فعليًا بمعرف الجهاز (Hardware ID)
// عبر core/licensing/hardware_id_generator.dart، بحيث لا يُفتح ملف قاعدة بيانات
// منسوخ لجهاز آخر إلا إذا طابق نفس المفتاح المشتق من ذلك الجهاز تحديدًا.
//
// تحذير أمني: عند البناء النهائي للإنتاج، يجب تفعيل Code Obfuscation
// (راجع docs/BUILD_GUIDE.md) حتى لا تظهر هذه القيمة بشكل مباشر في الملف التنفيذي.

class DatabaseEncryption {
  DatabaseEncryption._();

  // TODO: استبدل هذه القيمة قبل أي نسخة إنتاج فعلية، ولا تشاركها في أي مستودع علني.
  static const String _seedSecret = 'PharmaOS-Seed-2026-CHANGE-ME';

  /// يُرجع مفتاح التشفير الحالي المستخدم لفتح قاعدة البيانات.
  static String getEncryptionKey() {
    // TODO Phase 7: دمج Hardware ID هنا فعليًا بدلاً من القيمة الثابتة وحدها.
    return _seedSecret;
  }
}
