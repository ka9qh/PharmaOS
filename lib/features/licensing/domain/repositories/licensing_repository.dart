import '../entities/licensing_entity.dart';

abstract class LicensingRepository {
  Future<String> getHardwareId();

  /// يتحقق من وجود ترخيص محفوظ محليًا، ويُعيد التحقق من توقيعه ومطابقة
  /// معرف الجهاز الحالي في كل مرة (وليس مجرد الثقة بعلم "مُفعَّل" مخزَّن) -
  /// هذا يمنع نسخ ملف قاعدة البيانات مع ترخيص قديم إلى جهاز آخر غير مرخّص.
  Future<bool> hasValidLicense();

  Future<LicenseValidationOutcome> activate(String licenseKey);
}
