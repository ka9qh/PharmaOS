import '../entities/stock_alerts_entity.dart';
import '../repositories/stock_alerts_repository.dart';

class GetLowStockItemsUseCase {
  final StockAlertsRepository _repo;
  const GetLowStockItemsUseCase(this._repo);
  Future<List<StockSummary>> call() => _repo.getLowStockItems();
}
