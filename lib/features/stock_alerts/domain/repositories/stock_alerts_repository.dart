import '../entities/stock_alerts_entity.dart';

abstract class StockAlertsRepository {
  Future<List<StockSummary>> getLowStockItems();
}
