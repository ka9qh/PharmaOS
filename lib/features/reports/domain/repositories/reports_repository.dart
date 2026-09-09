import '../entities/reports_entity.dart';

abstract class ReportsRepository {
  /// معاينة حية لأرقام الفترة الحالية (منذ آخر إغلاق سابق، أو منذ بداية اليوم
  /// إذا لم يوجد إغلاق سابق إطلاقًا) - لا تُغلق أو تحفظ شيئًا، للعرض فقط.
  Future<DayClosingSummary> previewCurrentPeriod();

  /// وقت آخر إغلاق تم تسجيله (لعرضه في الواجهة كمعلومة، وليس لمنع أي شيء)
  Future<DateTime?> getLastClosingTime();

  /// ينشئ تقرير إغلاق فعليًا (نسخة احتياطية + PDF + Excel + Snapshot) دون قفل
  /// أي شيء - يمكن استدعاؤه عدة مرات في نفس اليوم (نوبات عمل متعددة).
  Future<DayClosingResult> closeCurrentPeriod({int? closedByUserId});

  Future<List<DayClosingRecordEntity>> listRecent({int limit = 30});

  /// حذف تقرير إغلاق خاطئ (وليس "إعادة فتح" - لا يوجد قفل من الأساس)
  Future<void> deleteClosingRecord(int id, {int? deletedBy});
}
