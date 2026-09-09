import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/entities/cash_register_entity.dart';
import '../../domain/repositories/cash_register_repository.dart';

class CashRegisterState {
  final bool isLoading;
  final List<WalletEntity> wallets;
  final List<TransactionEntity> currentTransactions;
  final double currentCashBalance;
  final int? selectedWalletId; // null means 'Cash Register'
  final String? errorMessage;

  CashRegisterState({
    this.isLoading = false,
    this.wallets = const [],
    this.currentTransactions = const [],
    this.currentCashBalance = 0.0,
    this.selectedWalletId,
    this.errorMessage,
  });

  CashRegisterState copyWith({
    bool? isLoading,
    List<WalletEntity>? wallets,
    List<TransactionEntity>? currentTransactions,
    double? currentCashBalance,
    int? selectedWalletId,
    bool clearSelectedWallet = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CashRegisterState(
      isLoading: isLoading ?? this.isLoading,
      wallets: wallets ?? this.wallets,
      currentTransactions: currentTransactions ?? this.currentTransactions,
      currentCashBalance: currentCashBalance ?? this.currentCashBalance,
      selectedWalletId: clearSelectedWallet ? null : (selectedWalletId ?? this.selectedWalletId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CashRegisterNotifier extends AutoDisposeNotifier<CashRegisterState> {
  late CashRegisterRepository _repository;

  @override
  CashRegisterState build() {
    _repository = sl<CashRegisterRepository>();
    Future.microtask(loadData);
    return CashRegisterState();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final wallets = await _repository.getWallets();
      final cashBalance = await _repository.getCashBalance();
      final txs = await _repository.getTransactions(walletId: state.selectedWalletId);
      state = state.copyWith(
        isLoading: false,
        wallets: wallets,
        currentCashBalance: cashBalance,
        currentTransactions: txs,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل بيانات الصندوق: $e');
    }
  }

  void selectWallet(int? walletId) {
    state = state.copyWith(selectedWalletId: walletId, clearSelectedWallet: walletId == null);
    loadData();
  }

  Future<void> addWallet(String name) async {
    if (name.trim().isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      await _repository.addWallet(name.trim());
      await loadData();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر إضافة المحفظة');
    }
  }

  Future<void> deleteWallet(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteWallet(id);
      if (state.selectedWalletId == id) {
        state = state.copyWith(clearSelectedWallet: true);
      }
      await loadData();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر حذف المحفظة. قد تكون مرتبطة بحركات مالية.');
    }
  }
}

final cashRegisterProvider = AutoDisposeNotifierProvider<CashRegisterNotifier, CashRegisterState>(CashRegisterNotifier.new);
