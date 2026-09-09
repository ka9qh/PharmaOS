class CustomWidgetEntity {
  final int id;
  final String keyName;
  final String location;
  final String widgetType;
  final String label;
  final String? iconName;
  final String? colorHex;
  final String? actionType;
  final String? actionData;
  final int sortOrder;
  final bool isVisible;

  const CustomWidgetEntity({
    required this.id,
    required this.keyName,
    required this.location,
    required this.widgetType,
    required this.label,
    this.iconName,
    this.colorHex,
    this.actionType,
    this.actionData,
    this.sortOrder = 0,
    this.isVisible = true,
  });
}
