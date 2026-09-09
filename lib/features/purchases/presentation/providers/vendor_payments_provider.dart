import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/repositories/purchases_repository.dart';
import '../../domain/usecases/purchases_usecase.dart';
import '../../../invoices/domain/repositories/invoices_repository.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';

class VendorPaymentsState {
  final bool isLoading;
  final List<InvoiceEntity> unpaidInvoices;
  final String? errorMessage;
  final int? supplierIdFilter;

  const VendorPaymentsState({
    this.isLoading = false,
    this.unpaidInvoices = const [],
    this.errorMessage,
    this.supplierIdFilter,
  });

  VendorPaymentsState copyWith({
    bool? isLoading,
    List<InvoiceEntity>? unpaidInvoices,
    String? errorMessage,
    bool clearError = false,
    int? supplierIdFilter,
    bool clearSupplierIdFilter = false,
  }) {
    return VendorPaymentsState(
      isLoading: isLoading ?? this.isLoading,
      unpaidInvoices: unpaidInvoices ?? this.unpaidInvoices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      supplierIdFilter: clearSupplierIdFilter ? null : (supplierIdFilter ?? this.supplierIdFilter),
    );
  }
}

class VendorPaymentsNotifier extends AutoDisposeNotifier<VendorPaymentsState> {
  @override
  VendorPaymentsState build() {
    return const VendorPaymentsState();
  }

  Future<void> loadUnpaidInvoices({int? supplierId}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      supplierIdFilter: supplierId,
      clearSupplierIdFilter: supplierId == null,
    );
    try {
      final list = await sl<InvoicesRepository>().searchPurchaseInvoices(
        onlyUnpaid: true,
        supplierId: supplierId,
      );
      state = state.copyWith(isLoading: false, unpaidInvoices: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر جلب الفواتير غير المسددة');
    }
  }

  Future<bool> recordPayment({
    required int purchaseId,
    required double amount,
    String paymentMethod = 'نقدي',
    String? notes,
    int? walletId,
  }) async {
    return addPayment(
      purchaseId: purchaseId,
      amount: amount,
      paymentMethod: paymentMethod,
      walletId: walletId,
    );
  }

  Future<bool> addPayment({
    required int purchaseId,
    required double amount,
    required String paymentMethod,
    int? walletId,
  }) async {
    try {
      await sl<PurchasesRepository>().addPaymentToPurchase(purchaseId: purchaseId, amount: amount, paymentMethod: paymentMethod, walletId: walletId);
      // Reload the list
      await loadUnpaidInvoices(supplierId: state.supplierIdFilter);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إضافة الدفعة');
      return false;
    }
  }
}

final vendorPaymentsNotifierProvider =
    AutoDisposeNotifierProvider<VendorPaymentsNotifier, VendorPaymentsState>(VendorPaymentsNotifier.new);
