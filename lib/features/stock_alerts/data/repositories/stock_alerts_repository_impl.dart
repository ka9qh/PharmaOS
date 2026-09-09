import '../../domain/entities/stock_alerts_entity.dart';
import '../../domain/repositories/stock_alerts_repository.dart';
import '../datasources/stock_alerts_datasource.dart';

class StockAlertsRepositoryImpl implements StockAlertsRepository {
  final StockAlertsDataSource dataSource;
  StockAlertsRepositoryImpl(this.dataSource);

  @override
  Future<List<StockSummary>> getLowStockItems() => dataSource.getLowStockItems();
}
