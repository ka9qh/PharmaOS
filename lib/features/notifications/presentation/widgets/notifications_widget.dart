import 'package:flutter/material.dart';
import '../../domain/entities/notifications_entity.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const NotificationTile({super.key, required this.notification});

  Color get _color {
    switch (notification.type) {
      case AppNotificationType.expired:
        return Colors.red;
      case AppNotificationType.expiringSoon:
        return Colors.orange;
      case AppNotificationType.lowStock:
        return Colors.orange;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case AppNotificationType.expired:
        return Icons.error_outline;
      case AppNotificationType.expiringSoon:
        return Icons.access_time;
      case AppNotificationType.lowStock:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_icon, color: _color),
      title: Text(notification.title),
      subtitle: Text(notification.subtitle),
    );
  }
}

/// أيقونة جرس بشارة رقمية - تُستخدم في AppBar لوحة التحكم
class NotificationBellIcon extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const NotificationBellIcon({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Badge(
        label: Text('$count'),
        isLabelVisible: count > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
