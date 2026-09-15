// شريط الإشعارات والتنبيهات العائم لتعديلات وتواصل المدير - PharmaOS
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OwnerNotificationItem {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  final VoidCallback? onTap;

  OwnerNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.icon = Icons.notifications_active_rounded,
    this.color = const Color(0xFF0D9488),
    required this.timestamp,
    this.onTap,
  });
}

class OwnerFloatingNotification {
  static final ValueNotifier<List<OwnerNotificationItem>> activeNotifications =
      ValueNotifier<List<OwnerNotificationItem>>([]);
  static final ValueNotifier<int> unreadMessagesCount = ValueNotifier<int>(0);

  /// إظهار إشعار جديد في أعلى الشاشة مع تنبيه صوتي وتأثير بصري
  static void show({
    required String title,
    required String message,
    IconData icon = Icons.admin_panel_settings_rounded,
    Color color = const Color(0xFF0D9488),
    VoidCallback? onTap,
  }) {
    final item = OwnerNotificationItem(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      icon: icon,
      color: color,
      timestamp: DateTime.now(),
      onTap: onTap,
    );

    // تشغيل تنبيه صوتي خفيف في النظام
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    final updated = List<OwnerNotificationItem>.from(activeNotifications.value)..insert(0, item);
    activeNotifications.value = updated;

    // إخفاء تلقائي بعد 7 ثوانٍ
    Timer(const Duration(seconds: 7), () {
      dismiss(item.id);
    });
  }

  static void dismiss(String id) {
    final updated = List<OwnerNotificationItem>.from(activeNotifications.value)
      ..removeWhere((n) => n.id == id);
    activeNotifications.value = updated;
  }

  static void incrementUnreadChat() {
    unreadMessagesCount.value += 1;
  }

  static void clearUnreadChat() {
    unreadMessagesCount.value = 0;
  }
}

/// ودجت عائم يوضع في أعلى شجرة التطبيق (Root Overlay) لعرض إشعارات المدير
class OwnerFloatingNotificationOverlay extends StatelessWidget {
  final Widget child;

  const OwnerFloatingNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          child,
          Positioned(
            top: 36,
            left: 24,
            width: 380,
            child: ValueListenableBuilder<List<OwnerNotificationItem>>(
              valueListenable: OwnerFloatingNotification.activeNotifications,
              builder: (context, notifs, _) {
                if (notifs.isEmpty) return const SizedBox.shrink();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: notifs.take(3).map((item) {
                    return _NotificationCard(item: item);
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final OwnerNotificationItem item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: item.color.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            OwnerFloatingNotification.dismiss(item.id);
            item.onTap?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              color: item.color,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.3,
                          fontFamily: 'Cairo',
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                  onPressed: () => OwnerFloatingNotification.dismiss(item.id),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
