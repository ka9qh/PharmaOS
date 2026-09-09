import '../../domain/entities/analytics_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_datasource.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsDataSource dataSource;
  AnalyticsRepositoryImpl(this.dataSource);

  @override
  Future<List<TopSellingMedicine>> getTopSellingMedicines({int limit = 5, int days = 30}) =>
      dataSource.getTopSellingMedicines(limit: limit, days: days);

  @override
  Future<SalesTrend> getWeeklySalesTrend() => dataSource.getWeeklySalesTrend();

  @override
  Future<List<ExpiringBatchInfo>> getExpiringSoonBatches({int daysThreshold = 30}) =>
      dataSource.getExpiringSoonBatches(daysThreshold: daysThreshold);
}
