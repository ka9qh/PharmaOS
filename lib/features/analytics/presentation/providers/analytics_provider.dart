import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/analytics_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/usecases/analytics_usecase.dart';

class AnalyticsState {
  final bool isLoading;
  final List<TopSellingMedicine> topSelling;
  final SalesTrend? salesTrend;
  final List<ExpiringBatchInfo> expiringSoon;
  final String? errorMessage;

  const AnalyticsState({
    this.isLoading = false,
    this.topSelling = const [],
    this.salesTrend,
    this.expiringSoon = const [],
    this.errorMessage,
  });

  AnalyticsState copyWith({
    bool? isLoading,
    List<TopSellingMedicine>? topSelling,
    SalesTrend? salesTrend,
    List<ExpiringBatchInfo>? expiringSoon,
    String? errorMessage,
  }) {
    return AnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      topSelling: topSelling ?? this.topSelling,
      salesTrend: salesTrend ?? this.salesTrend,
      expiringSoon: expiringSoon ?? this.expiringSoon,
      errorMessage: errorMessage,
    );
  }
}

class AnalyticsNotifier extends AutoDisposeNotifier<AnalyticsState> {
  @override
  AnalyticsState build() {
    Future.microtask(loadAll);
    return const AnalyticsState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = sl<AnalyticsRepository>();
      final topSelling = await GetTopSellingMedicinesUseCase(repo).call();
      final trend = await GetWeeklySalesTrendUseCase(repo).call();
      final expiring = await GetExpiringSoonBatchesUseCase(repo).call();
      state = state.copyWith(
        isLoading: false,
        topSelling: topSelling,
        salesTrend: trend,
        expiringSoon: expiring,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل التحليلات');
    }
  }
}

final analyticsNotifierProvider =
    AutoDisposeNotifierProvider<AnalyticsNotifier, AnalyticsState>(AnalyticsNotifier.new);
