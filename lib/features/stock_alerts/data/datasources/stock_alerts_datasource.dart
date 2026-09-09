import '../../../../core/services/stock_alert_service.dart';
import '../../../inventory/domain/entities/inventory_entity.dart';

class StockAlertsDataSource {
  final StockAlertService _service;
  StockAlertsDataSource(this._service);

  Future<List<StockSummary>> getLowStockItems() => _service.getLowStockItems();
}
