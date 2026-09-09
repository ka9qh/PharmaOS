// طبقة رقيقة فقط تُمرر الاستدعاءات إلى core/services/day_closing_service.dart

import '../../../../core/database/app_database.dart';
import '../../../../core/services/day_closing_service.dart';

class ReportsDataSource {
  final DayClosingService _service;
  ReportsDataSource(this._service);

  Future<DayClosingSummary> previewCurrentPeriod() => _service.computeCurrentPeriodSummary();
  Future<DateTime?> getLastClosingTime() => _service.getLastClosingTime();
  Future<DayClosingResult> closeCurrentPeriod({int? closedByUserId}) =>
      _service.closeCurrentPeriod(closedByUserId: closedByUserId);
  Future<List<DayClosingRow>> listRecent({int limit = 30}) => _service.listRecent(limit: limit);
  Future<void> deleteClosingRecord(int id) => _service.deleteClosingRecord(id);
}
