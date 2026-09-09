import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/suppliers_entity.dart';
import '../../domain/repositories/suppliers_repository.dart';
import '../../domain/usecases/suppliers_usecase.dart';

class PharmacyDebtsState {
  final bool isLoading;
  final List<SupplierDebt> debts;
  final String? errorMessage;

  const PharmacyDebtsState({
    this.isLoading = false,
    this.debts = const [],
    this.errorMessage,
  });

  List<SupplierDebt> get items => debts;
  double get totalDebts => debts.fold(0.0, (sum, d) => sum + d.remainingDebt);
  int get suppliersWithDebtCount => debts.where((d) => d.remainingDebt > 0).length;

  PharmacyDebtsState copyWith({
    bool? isLoading,
    List<SupplierDebt>? debts,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PharmacyDebtsState(
      isLoading: isLoading ?? this.isLoading,
      debts: debts ?? this.debts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SupplierDebt {
  final int supplierId;
  final String supplierName;
  final double totalPurchases;
  final double totalPaid;
  final double remainingDebt;

  SupplierDebt({
    required this.supplierId,
    required this.supplierName,
    required this.totalPurchases,
    required this.totalPaid,
    required this.remainingDebt,
  });
}

class PharmacyDebtsNotifier extends StateNotifier<PharmacyDebtsState> {
  final ListSuppliersUseCase useCase;

  PharmacyDebtsNotifier(this.useCase) : super(const PharmacyDebtsState()) {
    loadDebts();
  }

  Future<void> loadDebts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = sl<AppDatabase>();
      final suppliers = await useCase.call();
      final purchases = await db.select(db.purchases).get();
      final payments = await db.select(db.vendorPayments).get();

      final List<SupplierDebt> debtsList = [];

      for (var s in suppliers) {
        final supplierPurchases = purchases.where((p) => p.supplierId == s.id);
        final supplierPayments = payments.where((p) => p.supplierId == s.id);

        final totalPurchases = supplierPurchases.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
        final paidOnPurchases = supplierPurchases.fold<double>(0.0, (sum, p) => sum + p.paidAmount);
        final extraPaid = supplierPayments.fold<double>(0.0, (sum, p) => sum + p.amount);

        final totalPaid = paidOnPurchases + extraPaid;
        final remaining = (totalPurchases - totalPaid) > 0 ? (totalPurchases - totalPaid) : 0.0;

        if (totalPurchases > 0 || remaining > 0) {
          debtsList.add(SupplierDebt(
            supplierId: s.id,
            supplierName: s.name,
            totalPurchases: totalPurchases,
            totalPaid: totalPaid,
            remainingDebt: remaining,
          ));
        }
      }

      state = state.copyWith(isLoading: false, debts: debtsList);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final pharmacyDebtsNotifierProvider = StateNotifierProvider<PharmacyDebtsNotifier, PharmacyDebtsState>((ref) {
  final useCase = ListSuppliersUseCase(sl<SuppliersRepository>());
  return PharmacyDebtsNotifier(useCase);
});
