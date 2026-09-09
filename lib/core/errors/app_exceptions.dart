// استثناءات موحدة للتطبيق بدلاً من رسائل خطأ عشوائية غير مفهومة للمستخدم النهائي
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class InsufficientStockException extends AppException {
  InsufficientStockException([String? medicineName])
      : super(medicineName != null
            ? 'الكمية المطلوبة من "$medicineName" غير متوفرة في المخزون'
            : 'الكمية المطلوبة غير متوفرة في المخزون');
}

class InvalidLicenseException extends AppException {
  const InvalidLicenseException() : super('مفتاح الترخيص غير صالح لهذا الجهاز');
}

class ReturnQuantityExceededException extends AppException {
  ReturnQuantityExceededException([String? medicineName])
      : super(medicineName != null
            ? 'الكمية المطلوب إرجاعها من "$medicineName" أكبر من المسموح'
            : 'الكمية المطلوب إرجاعها أكبر من المسموح');
}
// TODO: إضافة بقية الاستثناءات حسب الحاجة أثناء التطوير
