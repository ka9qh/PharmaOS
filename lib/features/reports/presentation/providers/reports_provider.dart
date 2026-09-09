import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/reports_entity.dart';
import '../../domain/repositories/reports_repository.dart';
import '../../domain/usecases/reports_usecase.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ReportsState {
  final bool isLoading;
  final bool isClosing;
  final DateTime? lastClosingTime;
  final DayClosingSummary? preview;
  final DayClosingResult? lastResult;
  final List<DayClosingRecordEntity> recentClosings;
  final String? errorMessage;

  const ReportsState({
    this.isLoading = false,
    this.isClosing = false,
    this.lastClosingTime,
    this.preview,
    this.lastResult,
    this.recentClosings = const [],
    this.errorMessage,
  });

  ReportsState copyWith({
    bool? isLoading,
    bool? isClosing,
    DateTime? lastClosingTime,
    DayClosingSummary? preview,
    DayClosingResult? lastResult,
    List<DayClosingRecordEntity>? recentClosings,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      isClosing: isClosing ?? this.isClosing,
      lastClosingTime: lastClosingTime ?? this.lastClosingTime,
      preview: preview ?? this.preview,
      lastResult: lastResult ?? this.lastResult,
      recentClosings: recentClosings ?? this.recentClosings,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ReportsNotifier extends AutoDisposeNotifier<ReportsState> {
  @override
  ReportsState build() {
    Future.microtask(loadInitial);
    return const ReportsState();
  }

  /// لا يوجد "قفل" في هذا النظام - إغلاق نوبة لا يمنع أي عملية لاحقة، ويمكن
  /// تكرار الإغلاق عدة مرات في نفس اليوم لصيدليات العمل بنظام النوبات.
  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final lastClosing = await GetLastClosingTimeUseCase(sl<ReportsRepository>()).call();
      final preview = await PreviewCurrentPeriodUseCase(sl<ReportsRepository>()).call();
      final recent = await ListRecentClosingsUseCase(sl<ReportsRepository>()).call();
      state = state.copyWith(
        isLoading: false,
        lastClosingTime: lastClosing,
        preview: preview,
        recentClosings: recent,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل بيانات التقارير');
    }
  }

  Future<bool> closeCurrentPeriod() async {
    state = state.copyWith(isClosing: true, clearError: true);
    try {
      final closedBy = ref.read(authNotifierProvider).user?.id;
      final result =
          await CloseCurrentPeriodUseCase(sl<ReportsRepository>()).call(closedByUserId: closedBy);
      state = state.copyWith(isClosing: false, lastResult: result);
      await loadInitial();
      return true;
    } catch (e) {
      state = state.copyWith(isClosing: false, errorMessage: 'تعذر إصدار تقرير الإغلاق');
      return false;
    }
  }

  Future<bool> deleteClosingRecord(int id) async {
    try {
      final deletedBy = ref.read(authNotifierProvider).user?.id;
      await DeleteClosingRecordUseCase(sl<ReportsRepository>()).call(id, deletedBy: deletedBy);
      await loadInitial();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حذف تقرير الإغلاق');
      return false;
    }
  }
}

final reportsNotifierProvider =
    AutoDisposeNotifierProvider<ReportsNotifier, ReportsState>(ReportsNotifier.new);
