import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/entities/ledger_entry_entity.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/get_supplier_ledger_usecase.dart';
import '../../data/datasources/supplier_ledger_datasource.dart';

class SupplierLedgerState {
  final bool isLoading;
  final List<LedgerEntryEntity> entries;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? errorMessage;

  const SupplierLedgerState({
    this.isLoading = false,
    this.entries = const [],
    this.startDate,
    this.endDate,
    this.errorMessage,
  });

  SupplierLedgerState copyWith({
    bool? isLoading,
    List<LedgerEntryEntity>? entries,
    DateTime? startDate,
    DateTime? endDate,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupplierLedgerState(
      isLoading: isLoading ?? this.isLoading,
      entries: entries ?? this.entries,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SupplierLedgerNotifier extends StateNotifier<SupplierLedgerState> {
  SupplierLedgerNotifier() : super(const SupplierLedgerState());

  Future<void> loadLedger(int supplierId, {DateTime? start, DateTime? end}) async {
    state = state.copyWith(isLoading: true, startDate: start, endDate: end, clearError: true);
    try {
      final useCase = GetSupplierLedgerUseCase(sl<SupplierLedgerDataSource>());
      final entries = await useCase.call(supplierId, startDate: start, endDate: end);
      state = state.copyWith(isLoading: false, entries: entries, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل كشف حساب المورد: ${e.toString()}',
      );
    }
  }
}

final supplierLedgerNotifierProvider =
    StateNotifierProvider<SupplierLedgerNotifier, SupplierLedgerState>((ref) {
  return SupplierLedgerNotifier();
});
