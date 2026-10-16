import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/entities/ledger_entry_entity.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/get_customer_ledger_usecase.dart';
import '../../data/datasources/customer_ledger_datasource.dart';

class CustomerLedgerState {
  final bool isLoading;
  final List<LedgerEntryEntity> entries;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? errorMessage;

  const CustomerLedgerState({
    this.isLoading = false,
    this.entries = const [],
    this.startDate,
    this.endDate,
    this.errorMessage,
  });

  CustomerLedgerState copyWith({
    bool? isLoading,
    List<LedgerEntryEntity>? entries,
    DateTime? startDate,
    DateTime? endDate,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomerLedgerState(
      isLoading: isLoading ?? this.isLoading,
      entries: entries ?? this.entries,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CustomerLedgerNotifier extends StateNotifier<CustomerLedgerState> {
  CustomerLedgerNotifier() : super(const CustomerLedgerState());

  Future<void> loadLedger(int customerId, {DateTime? start, DateTime? end}) async {
    state = state.copyWith(isLoading: true, startDate: start, endDate: end, clearError: true);
    try {
      final useCase = GetCustomerLedgerUseCase(sl<CustomerLedgerDataSource>());
      final entries = await useCase.call(customerId, startDate: start, endDate: end);
      state = state.copyWith(isLoading: false, entries: entries, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل كشف حساب العميل: $e',
      );
    }
  }
}

final customerLedgerNotifierProvider =
    StateNotifierProvider<CustomerLedgerNotifier, CustomerLedgerState>((ref) {
  return CustomerLedgerNotifier();
});
