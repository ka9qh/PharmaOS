class AuditLogEntryEntity {
  final int id;
  final String actionType;
  final String tableName;
  final String? recordId;
  final String? userName;
  final DateTime timestamp;

  const AuditLogEntryEntity({
    required this.id,
    required this.actionType,
    required this.tableName,
    this.recordId,
    this.userName,
    required this.timestamp,
  });

  /// وصف مبسّط بالعربية لنوع العملية - يُستخدم في "آخر العمليات" بالداشبورد
  String get friendlyDescription {
    switch (actionType) {
      case 'LOGIN_SUCCESS':
        return 'تسجيل دخول ناجح';
      case 'LOGIN_FAILED':
        return 'محاولة دخول فاشلة';
      case 'LOGOUT':
        return 'تسجيل خروج';
      case 'SALE_CREATED':
        return 'عملية بيع جديدة';
      case 'EXPENSE_RECORDED':
        return 'تسجيل مصروف';
      case 'PURCHASE_CREATED':
        return 'فاتورة شراء جديدة';
      case 'CUSTOMER_RETURN':
        return 'مرتجع عميل';
      case 'VENDOR_RETURN':
        return 'مرتجع مورد';
      case 'PERIOD_CLOSED':
        return 'إصدار تقرير إغلاق';
      case 'CLOSING_RECORD_DELETED':
        return 'حذف تقرير إغلاق';
      default:
        return actionType;
    }
  }
}
