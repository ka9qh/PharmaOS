import 'package:drift/drift.dart';

@DataClassName('CustomWidgetDef')
class CustomWidgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get keyName => text().unique()(); // e.g. "dashboard_custom_btn_1"
  TextColumn get location => text()(); // e.g. "dashboard", "pos", "settings"
  TextColumn get widgetType => text()(); // e.g. "button", "search", "html_page"
  TextColumn get label => text()(); // The button or widget label
  TextColumn get iconName => text().nullable()(); // Material icon name
  TextColumn get colorHex => text().nullable()(); // e.g. "#FF0000"
  TextColumn get actionType => text().nullable()(); // e.g. "open_url", "open_html", "navigate"
  TextColumn get actionData => text().nullable()(); // e.g. HTML content, or URL, or Route Name
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
}
