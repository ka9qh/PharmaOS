import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/expiry_alert_entity.dart';
import '../../domain/repositories/stock_alerts_repository.dart';
import '../../domain/usecases/get_expiring_batches_usecase.dart';

class ExpiryAlertsState {
  final bool isLoading;
  final List<ExpiryAlertEntity> items;

  const ExpiryAlertsState({this.isLoading = false, this.items = const []});

  ExpiryAlertsState copyWith({bool? isLoading, List<ExpiryAlertEntity>? items}) {
    return ExpiryAlertsState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
    );
  }
}

class ExpiryAlertsNotifier extends AutoDisposeNotifier<ExpiryAlertsState> {
  @override
  ExpiryAlertsState build() {
    Future.microtask(loadAll);
    return const ExpiryAlertsState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final usecase = GetExpiringBatchesUseCase(sl<StockAlertsRepository>());
    // جلب الأدوية التي ستنتهي خلال 6 أشهر
    final items = await usecase.call(withinDays: 180);
    state = state.copyWith(isLoading: false, items: items);
  }
}

final expiryAlertsNotifierProvider =
    AutoDisposeNotifierProvider<ExpiryAlertsNotifier, ExpiryAlertsState>(ExpiryAlertsNotifier.new);
