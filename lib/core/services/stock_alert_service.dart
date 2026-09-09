// يعيد فقط الأدوية التي وصلت كميتها لحد التنبيه (Reorder Level) أو أقل
// TODO Phase 6: ربط هذا بنظام إشعارات مرئي دائم في الواجهة (Notifications)
// حاليًا يُستخدم في تقرير إغلاق اليومية فقط.

import '../../features/inventory/domain/entities/inventory_entity.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';

class StockAlertService {
  final InventoryRepository _inventoryRepository;
  StockAlertService(this._inventoryRepository);

  Future<List<StockSummary>> getLowStockItems() async {
    final all = await _inventoryRepository.getStockOverview();
    return all.where((s) => s.isLow).toList();
  }
}
