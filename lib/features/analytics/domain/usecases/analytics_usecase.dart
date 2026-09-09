import '../entities/analytics_entity.dart';
import '../repositories/analytics_repository.dart';

class GetTopSellingMedicinesUseCase {
  final AnalyticsRepository _repo;
  const GetTopSellingMedicinesUseCase(this._repo);
  Future<List<TopSellingMedicine>> call({int limit = 5, int days = 30}) =>
      _repo.getTopSellingMedicines(limit: limit, days: days);
}

class GetWeeklySalesTrendUseCase {
  final AnalyticsRepository _repo;
  const GetWeeklySalesTrendUseCase(this._repo);
  Future<SalesTrend> call() => _repo.getWeeklySalesTrend();
}

class GetExpiringSoonBatchesUseCase {
  final AnalyticsRepository _repo;
  const GetExpiringSoonBatchesUseCase(this._repo);
  Future<List<ExpiringBatchInfo>> call({int daysThreshold = 30}) =>
      _repo.getExpiringSoonBatches(daysThreshold: daysThreshold);
}
