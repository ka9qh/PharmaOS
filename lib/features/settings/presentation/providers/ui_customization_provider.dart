import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../data/repositories/ui_customization_repository.dart';
import '../../domain/entities/custom_widget_entity.dart';

final uiCustomizationRepoProvider = Provider<UiCustomizationRepository>((ref) {
  return UiCustomizationRepository(sl<AppDatabase>());
});

final uiStringsProvider = StateNotifierProvider<UiStringsNotifier, Map<String, String>>((ref) {
  final repo = ref.watch(uiCustomizationRepoProvider);
  return UiStringsNotifier(repo);
});

class UiStringsNotifier extends StateNotifier<Map<String, String>> {
  final UiCustomizationRepository _repo;

  UiStringsNotifier(this._repo) : super({}) {
    load();
  }

  Future<void> load() async {
    final strings = await _repo.getAllStrings();
    state = strings;
  }

  Future<void> setString(String key, String value, {String? module}) async {
    await _repo.setString(key, value, module: module);
    state = {...state, key: value};
  }

  Future<void> deleteString(String key) async {
    await _repo.deleteString(key);
    final newState = Map<String, String>.from(state)..remove(key);
    state = newState;
  }

  String get(String key, {String? fallback}) {
    return state[key] ?? fallback ?? key;
  }
}

final customWidgetsProvider = StateNotifierProvider<CustomWidgetsNotifier, AsyncValue<List<CustomWidgetEntity>>>((ref) {
  final repo = ref.watch(uiCustomizationRepoProvider);
  return CustomWidgetsNotifier(repo);
});

class CustomWidgetsNotifier extends StateNotifier<AsyncValue<List<CustomWidgetEntity>>> {
  final UiCustomizationRepository _repo;

  CustomWidgetsNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadAll();
  }

  Future<void> loadAll() async {
    try {
      final widgets = await _repo.getAllCustomWidgets();
      state = AsyncValue.data(widgets);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addWidget(CustomWidgetEntity entity) async {
    await _repo.addCustomWidget(entity);
    await loadAll();
  }

  Future<void> updateWidget(CustomWidgetEntity entity) async {
    await _repo.updateCustomWidget(entity);
    await loadAll();
  }

  Future<void> deleteWidget(int id) async {
    await _repo.deleteCustomWidget(id);
    await loadAll();
  }
}
