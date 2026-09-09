enum AppNotificationType { lowStock, expiringSoon, expired }

class AppNotification {
  final AppNotificationType type;
  final String title;
  final String subtitle;

  const AppNotification({required this.type, required this.title, required this.subtitle});
}
