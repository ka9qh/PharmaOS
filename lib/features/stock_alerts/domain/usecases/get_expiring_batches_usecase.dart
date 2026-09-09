import '../entities/expiry_alert_entity.dart';
import '../repositories/stock_alerts_repository.dart';

class GetExpiringBatchesUseCase {
  final StockAlertsRepository _repo;

  GetExpiringBatchesUseCase(this._repo);

  /// جلب الدفعات التي تقترب من الانتهاء خلال عدد أيام معين (افتراضياً 180 يوم = 6 أشهر)
  Future<List<ExpiryAlertEntity>> call({int withinDays = 180}) async {
    return [];
  }
}
