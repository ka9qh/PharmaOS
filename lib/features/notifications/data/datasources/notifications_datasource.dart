import '../../../../core/services/stock_alert_service.dart';
import '../../../../core/services/local_analytics_service.dart';
import '../../domain/entities/notifications_entity.dart';

class NotificationsDataSource {
  final StockAlertService _stockAlertService;
  final LocalAnalyticsService _analyticsService;

  NotificationsDataSource(this._stockAlertService, this._analyticsService);

  Future<List<AppNotification>> getAll() async {
    final notifications = <AppNotification>[];

    final lowStock = await _stockAlertService.getLowStockItems();
    for (final item in lowStock) {
      notifications.add(AppNotification(
        type: AppNotificationType.lowStock,
        title: 'نقص مخزون: ${item.medicineName}',
        subtitle: 'المتبقي ${item.totalQuantity} (حد التنبيه ${item.reorderLevel})',
      ));
    }

    final expiring = await _analyticsService.getExpiringSoonBatches(daysThreshold: 30);
    for (final batch in expiring) {
      if (batch.isAlreadyExpired) {
        notifications.add(AppNotification(
          type: AppNotificationType.expired,
          title: 'منتهي الصلاحية: ${batch.medicineName}',
          subtitle: 'الكمية: ${batch.quantity}',
        ));
      } else {
        notifications.add(AppNotification(
          type: AppNotificationType.expiringSoon,
          title: 'قرب انتهاء الصلاحية: ${batch.medicineName}',
          subtitle: 'خلال ${batch.daysUntilExpiry} يومًا (الكمية: ${batch.quantity})',
        ));
      }
    }

    return notifications;
  }

  Future<int> getTotalCount() async => (await getAll()).length;
}
