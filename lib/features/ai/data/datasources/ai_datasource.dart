// يبني قائمة رؤى نصية بالعربية من بيانات حقيقية - كل رسالة مبنية على رقم فعلي
// محسوب مسبقًا، وليس نصًا مولَّدًا بذكاء اصطناعي. أمثلة الصياغة مأخوذة من
// docs/AI_DEVELOPMENT_GUIDE.md حرفيًا.

import '../../../../core/services/local_analytics_service.dart';
import '../../../../core/services/stock_alert_service.dart';
import '../../domain/entities/ai_entity.dart';

class AiDataSource {
  final LocalAnalyticsService _analyticsService;
  final StockAlertService _stockAlertService;

  AiDataSource(this._analyticsService, this._stockAlertService);

  Future<List<AiInsight>> generateInsights() async {
    final insights = <AiInsight>[];

    // 1) اتجاه المبيعات الأسبوعي
    final trend = await _analyticsService.getWeeklySalesTrend();
    final change = trend.percentChange;
    if (change != null) {
      final direction = trend.isUp ? 'ارتفعت' : 'انخفضت';
      insights.add(AiInsight(
        message: 'مبيعات هذا الأسبوع $direction بنسبة ${change.abs().toStringAsFixed(0)}٪ '
            'مقارنة بالأسبوع الماضي.',
        severity: trend.isUp ? InsightSeverity.info : InsightSeverity.warning,
      ));
    }

    // 2) الأدوية الأكثر مبيعًا
    final topSelling = await _analyticsService.getTopSellingMedicines(limit: 1, days: 7);
    if (topSelling.isNotEmpty) {
      final top = topSelling.first;
      insights.add(AiInsight(
        message: 'الأكثر مبيعًا هذا الأسبوع: ${top.medicineName} (${top.totalQuantitySold} وحدة).',
        severity: InsightSeverity.info,
      ));
    }

    // 3) نقص المخزون
    final lowStock = await _stockAlertService.getLowStockItems();
    for (final item in lowStock.take(5)) {
      insights.add(AiInsight(
        message: 'ينصح بطلب دواء "${item.medicineName}" قريبًا - '
            'الكمية المتبقية (${item.totalQuantity}) عند أو أقل من حد التنبيه (${item.reorderLevel}).',
        severity: InsightSeverity.warning,
      ));
    }
    if (lowStock.length > 5) {
      insights.add(AiInsight(
        message: 'وهناك ${lowStock.length - 5} دواءً إضافيًا تحت حد التنبيه - راجع شاشة المخزون.',
        severity: InsightSeverity.warning,
      ));
    }

    // 4) أدوية قاربت على الانتهاء أو منتهية بالفعل
    final expiring = await _analyticsService.getExpiringSoonBatches(daysThreshold: 30);
    final alreadyExpired = expiring.where((b) => b.isAlreadyExpired).toList();
    final expiringSoon = expiring.where((b) => !b.isAlreadyExpired).toList();

    if (alreadyExpired.isNotEmpty) {
      insights.add(AiInsight(
        message: 'يوجد ${alreadyExpired.length} صنفًا منتهي الصلاحية بالفعل في المخزون - '
            'يُنصح بإزالته والتحقق من إمكانية إرجاعه للمورد.',
        severity: InsightSeverity.critical,
      ));
    }
    for (final batch in expiringSoon.take(3)) {
      insights.add(AiInsight(
        message: 'هناك ${batch.quantity} من "${batch.medicineName}" ستنتهي صلاحيته '
            'خلال ${batch.daysUntilExpiry} يومًا.',
        severity: InsightSeverity.warning,
      ));
    }

    if (insights.isEmpty) {
      insights.add(const AiInsight(
        message: 'لا توجد ملاحظات هامة حاليًا - كل شيء يبدو طبيعيًا 👍',
        severity: InsightSeverity.info,
      ));
    }

    return insights;
  }
}
