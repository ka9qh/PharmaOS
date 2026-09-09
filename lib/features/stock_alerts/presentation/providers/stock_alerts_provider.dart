import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/stock_alerts_entity.dart';
import '../../domain/repositories/stock_alerts_repository.dart';
import '../../domain/usecases/stock_alerts_usecase.dart';

class StockAlertsState {
  final bool isLoading;
  final List<StockSummary> items;

  const StockAlertsState({this.isLoading = false, this.items = const []});

  StockAlertsState copyWith({bool? isLoading, List<StockSummary>? items}) {
    return StockAlertsState(isLoading: isLoading ?? this.isLoading, items: items ?? this.items);
  }
}

class StockAlertsNotifier extends AutoDisposeNotifier<StockAlertsState> {
  @override
  StockAlertsState build() {
    Future.microtask(loadAll);
    return const StockAlertsState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final items = await GetLowStockItemsUseCase(sl<StockAlertsRepository>()).call();
    state = state.copyWith(isLoading: false, items: items);
  }
}

final stockAlertsNotifierProvider =
    AutoDisposeNotifierProvider<StockAlertsNotifier, StockAlertsState>(StockAlertsNotifier.new);
