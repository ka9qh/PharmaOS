import '../../../../core/services/local_analytics_service.dart';

class AnalyticsDataSource {
  final LocalAnalyticsService _service;
  AnalyticsDataSource(this._service);

  Future<List<TopSellingMedicine>> getTopSellingMedicines({int limit = 5, int days = 30}) =>
      _service.getTopSellingMedicines(limit: limit, days: days);

  Future<SalesTrend> getWeeklySalesTrend() => _service.getWeeklySalesTrend();

  Future<List<ExpiringBatchInfo>> getExpiringSoonBatches({int daysThreshold = 30}) =>
      _service.getExpiringSoonBatches(daysThreshold: daysThreshold);
}
