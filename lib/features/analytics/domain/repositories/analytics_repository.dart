import '../entities/analytics_entity.dart';

abstract class AnalyticsRepository {
  Future<List<TopSellingMedicine>> getTopSellingMedicines({int limit = 5, int days = 30});
  Future<SalesTrend> getWeeklySalesTrend();
  Future<List<ExpiringBatchInfo>> getExpiringSoonBatches({int daysThreshold = 30});
}
