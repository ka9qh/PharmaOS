import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/custom_widget_entity.dart';

class UiCustomizationRepository {
  final AppDatabase _db;

  UiCustomizationRepository(this._db);

  // --- Strings ---
  Future<Map<String, String>> getAllStrings() async {
    final rows = await _db.select(_db.uiStrings).get();
    return {for (var r in rows) r.keyName: r.valueAr};
  }

  Future<void> setString(String key, String value, {String? module}) async {
    await _db.into(_db.uiStrings).insertOnConflictUpdate(
          UiString(keyName: key, valueAr: value, module: module),
        );
  }
  
  Future<void> deleteString(String key) async {
    await (_db.delete(_db.uiStrings)..where((t) => t.keyName.equals(key))).go();
  }

  // --- Custom Widgets ---
  Future<List<CustomWidgetEntity>> getCustomWidgets(String location) async {
    final rows = await (_db.select(_db.customWidgets)..where((t) => t.location.equals(location))..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();
    return rows
        .map((r) => CustomWidgetEntity(
              id: r.id,
              keyName: r.keyName,
              location: r.location,
              widgetType: r.widgetType,
              label: r.label,
              iconName: r.iconName,
              colorHex: r.colorHex,
              actionType: r.actionType,
              actionData: r.actionData,
              sortOrder: r.sortOrder,
              isVisible: r.isVisible,
            ))
        .toList();
  }
  
  Future<List<CustomWidgetEntity>> getAllCustomWidgets() async {
    final rows = await _db.select(_db.customWidgets).get();
    return rows
        .map((r) => CustomWidgetEntity(
              id: r.id,
              keyName: r.keyName,
              location: r.location,
              widgetType: r.widgetType,
              label: r.label,
              iconName: r.iconName,
              colorHex: r.colorHex,
              actionType: r.actionType,
              actionData: r.actionData,
              sortOrder: r.sortOrder,
              isVisible: r.isVisible,
            ))
        .toList();
  }

  Future<void> addCustomWidget(CustomWidgetEntity entity) async {
    await _db.into(_db.customWidgets).insert(
          CustomWidgetsCompanion.insert(
            keyName: entity.keyName,
            location: entity.location,
            widgetType: entity.widgetType,
            label: entity.label,
            iconName: Value(entity.iconName),
            colorHex: Value(entity.colorHex),
            actionType: Value(entity.actionType),
            actionData: Value(entity.actionData),
            sortOrder: Value(entity.sortOrder),
            isVisible: Value(entity.isVisible),
          ),
        );
  }

  Future<void> updateCustomWidget(CustomWidgetEntity entity) async {
    await (_db.update(_db.customWidgets)..where((t) => t.id.equals(entity.id))).write(
      CustomWidgetsCompanion(
        keyName: Value(entity.keyName),
        location: Value(entity.location),
        widgetType: Value(entity.widgetType),
        label: Value(entity.label),
        iconName: Value(entity.iconName),
        colorHex: Value(entity.colorHex),
        actionType: Value(entity.actionType),
        actionData: Value(entity.actionData),
        sortOrder: Value(entity.sortOrder),
        isVisible: Value(entity.isVisible),
      ),
    );
  }

  Future<void> deleteCustomWidget(int id) async {
    await (_db.delete(_db.customWidgets)..where((t) => t.id.equals(id))).go();
  }
}
