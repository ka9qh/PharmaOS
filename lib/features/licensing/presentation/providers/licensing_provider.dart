import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/licensing_entity.dart';
import '../../domain/repositories/licensing_repository.dart';
import '../../domain/usecases/licensing_usecase.dart';

class LicensingState {
  final bool isLoading;
  final bool isActivating;
  final String? hardwareId;
  final bool isLicensed;
  final String? errorMessage;

  const LicensingState({
    this.isLoading = false,
    this.isActivating = false,
    this.hardwareId,
    this.isLicensed = false,
    this.errorMessage,
  });

  LicensingState copyWith({
    bool? isLoading,
    bool? isActivating,
    String? hardwareId,
    bool? isLicensed,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LicensingState(
      isLoading: isLoading ?? this.isLoading,
      isActivating: isActivating ?? this.isActivating,
      hardwareId: hardwareId ?? this.hardwareId,
      isLicensed: isLicensed ?? this.isLicensed,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LicensingNotifier extends AutoDisposeNotifier<LicensingState> {
  @override
  LicensingState build() {
    Future.microtask(loadStatus);
    return const LicensingState(isLoading: true);
  }

  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = sl<LicensingRepository>();
      final hwid = await GetHardwareIdUseCase(repo).call();
      final licensed = await HasValidLicenseUseCase(repo).call();
      state = state.copyWith(isLoading: false, hardwareId: hwid, isLicensed: licensed);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر التحقق من الترخيص');
    }
  }

  Future<bool> activate(String licenseKey) async {
    state = state.copyWith(isActivating: true, clearError: true);
    try {
      final outcome = await ActivateLicenseUseCase(sl<LicensingRepository>()).call(licenseKey);
      if (outcome.isValid) {
        state = state.copyWith(isActivating: false, isLicensed: true);
        return true;
      }
      state = state.copyWith(isActivating: false, errorMessage: _messageFor(outcome.result));
      return false;
    } catch (e) {
      state = state.copyWith(isActivating: false, errorMessage: 'تعذر تفعيل الترخيص');
      return false;
    }
  }

  String _messageFor(LicenseCheckResult result) {
    switch (result) {
      case LicenseCheckResult.malformed:
        return 'صيغة مفتاح الترخيص غير صحيحة - تأكد من نسخه كاملاً';
      case LicenseCheckResult.invalidSignature:
        return 'مفتاح الترخيص غير صالح';
      case LicenseCheckResult.hardwareMismatch:
        return 'هذا المفتاح صادر لجهاز آخر مختلف عن هذا الجهاز';
      case LicenseCheckResult.expired:
        return 'انتهت صلاحية هذا الترخيص - تواصل لتجديده';
      case LicenseCheckResult.valid:
        return '';
    }
  }
}

final licensingNotifierProvider =
    AutoDisposeNotifierProvider<LicensingNotifier, LicensingState>(LicensingNotifier.new);
