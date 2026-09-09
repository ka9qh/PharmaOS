import '../entities/sales_entity.dart';

abstract class SalesRepository {
  /// ينشئ فاتورة بيع كاملة بشكل ذرّي (Atomic Transaction):
  /// يخصم المخزون بمنطق FEFO (الأقرب انتهاءً أولًا)، ويسجل بنود الفاتورة،
  /// ويتراجع تلقائيًا عن كل شيء إذا كانت أي كمية غير متوفرة (Rollback).
  Future<SaleEntity> createSale({
    required List<CartLineInput> items,
    required double discount,
    required String paymentMethod,
    int? cashierId,
    int? customerId,
    int? doctorId,
    int? prescriptionId,
  });

  /// إجمالي مبيعات اليوم الحالي - يُستخدم كمؤشر سريع في شاشة نقطة البيع
  /// (وليس بديلاً عن تقرير إغلاق اليومية الكامل في Phase 5).
  Future<double> getTodaySalesTotal();

  // تعليق الفواتير
  Future<void> suspendSale({
    required List<CartLineInput> items,
    int? cashierId,
    int? customerId,
    String? referenceNote,
  });
  Future<List<Map<String, dynamic>>> getSuspendedSales();
  Future<void> deleteSuspendedSale(int id);
}
