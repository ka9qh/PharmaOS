import '../entities/notifications_entity.dart';

abstract class NotificationsRepository {
  /// عدد التنبيهات الإجمالي - يُستخدم كشارة رقمية (Badge) في الداشبورد
  Future<int> getTotalCount();

  /// القائمة الكاملة المُجمَّعة (نقص مخزون + قرب انتهاء + منتهي بالفعل)
  Future<List<AppNotification>> getAll();
}
