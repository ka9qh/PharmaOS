import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/settings_usecase.dart';

class SettingsState {
  final bool isLoading;
  final bool isSaving;
  final PharmacySettings settings;
  final String? successMessage;

  const SettingsState({
    this.isLoading = false,
    this.isSaving = false,
    this.settings = const PharmacySettings(),
    this.successMessage,
  });

  SettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    PharmacySettings? settings,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      settings: settings ?? this.settings,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    Future.microtask(load);
    return const SettingsState(isLoading: true);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final settings = await LoadSettingsUseCase(sl<SettingsRepository>()).call();
    state = state.copyWith(isLoading: false, settings: settings);
  }

  Future<void> save(PharmacySettings settings) async {
    state = state.copyWith(isSaving: true, clearSuccess: true);
    await SaveSettingsUseCase(sl<SettingsRepository>()).call(settings);
    state = state.copyWith(isSaving: false, settings: settings, successMessage: 'تم حفظ الإعدادات بنجاح');
  }
}

final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
