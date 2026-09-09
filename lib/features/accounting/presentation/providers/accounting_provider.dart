import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/accounting_entity.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../../domain/usecases/accounting_usecase.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AccountingState {
  final bool isLoading;
  final List<SupplierBalance> balances;
  final String? errorMessage;

  const AccountingState({
    this.isLoading = false,
    this.balances = const [],
    this.errorMessage,
  });

  AccountingState copyWith({
    bool? isLoading,
    List<SupplierBalance>? balances,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AccountingState(
      isLoading: isLoading ?? this.isLoading,
      balances: balances ?? this.balances,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AccountingNotifier extends AutoDisposeNotifier<AccountingState> {
  @override
  AccountingState build() {
    Future.microtask(loadAll);
    return const AccountingState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await GetSupplierBalancesUseCase(sl<AccountingRepository>()).call();
      state = state.copyWith(isLoading: false, balances: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل أرصدة الموردين');
    }
  }

  Future<bool> recordPayment({required int supplierId, required double amount, String? notes}) async {
    try {
      final recordedBy = ref.read(authNotifierProvider).user?.id;
      await RecordVendorPaymentUseCase(sl<AccountingRepository>()).call(
        supplierId: supplierId,
        amount: amount,
        notes: notes,
        recordedBy: recordedBy,
      );
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تسجيل التسديد');
      return false;
    }
  }
}

final accountingNotifierProvider =
    AutoDisposeNotifierProvider<AccountingNotifier, AccountingState>(AccountingNotifier.new);
