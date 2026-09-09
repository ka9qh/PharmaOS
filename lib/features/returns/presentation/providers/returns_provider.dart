import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/returns_entity.dart';
import '../../domain/repositories/returns_repository.dart';
import '../../domain/usecases/returns_usecase.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ReturnsState {
  final bool isSearching;
  final bool isProcessing;
  final SaleLookupResult? saleResult;
  final PurchaseLookupResult? purchaseResult;
  final String? errorMessage;
  final String? successMessage;

  const ReturnsState({
    this.isSearching = false,
    this.isProcessing = false,
    this.saleResult,
    this.purchaseResult,
    this.errorMessage,
    this.successMessage,
  });

  ReturnsState copyWith({
    bool? isSearching,
    bool? isProcessing,
    SaleLookupResult? saleResult,
    PurchaseLookupResult? purchaseResult,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearResults = false,
  }) {
    return ReturnsState(
      isSearching: isSearching ?? this.isSearching,
      isProcessing: isProcessing ?? this.isProcessing,
      saleResult: clearResults ? null : (saleResult ?? this.saleResult),
      purchaseResult: clearResults ? null : (purchaseResult ?? this.purchaseResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ReturnsNotifier extends AutoDisposeNotifier<ReturnsState> {
  @override
  ReturnsState build() => const ReturnsState();

  Future<void> searchSale(String invoiceNumber) async {
    state = state.copyWith(isSearching: true, clearError: true, clearResults: true, clearSuccess: true);
    try {
      final result =
          await FindSaleByInvoiceUseCase(sl<ReturnsRepository>()).call(invoiceNumber);
      if (result == null) {
        state = state.copyWith(isSearching: false, errorMessage: 'لا توجد فاتورة بهذا الرقم');
      } else {
        state = state.copyWith(isSearching: false, saleResult: result);
      }
    } catch (e) {
      state = state.copyWith(isSearching: false, errorMessage: 'تعذر البحث عن الفاتورة');
    }
  }

  Future<void> searchPurchase(String purchaseNumber) async {
    state = state.copyWith(isSearching: true, clearError: true, clearResults: true, clearSuccess: true);
    try {
      final result =
          await FindPurchaseByNumberUseCase(sl<ReturnsRepository>()).call(purchaseNumber);
      if (result == null) {
        state = state.copyWith(isSearching: false, errorMessage: 'لا توجد فاتورة شراء بهذا الرقم');
      } else {
        state = state.copyWith(isSearching: false, purchaseResult: result);
      }
    } catch (e) {
      state = state.copyWith(isSearching: false, errorMessage: 'تعذر البحث عن فاتورة الشراء');
    }
  }

  Future<bool> submitCustomerReturn({
    required int saleItemId,
    required int quantity,
    required int qtyCarton,
    required int qtyPack,
    required int qtyStrip,
    required int qtyPill,
    required double refundAmount,
    required String settlementMethod,
    required String paymentMethod,
    int? walletId,
    String? reason,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true, clearSuccess: true);
    try {
      final processedBy = ref.read(authNotifierProvider).user?.id;
      await CreateCustomerReturnUseCase(sl<ReturnsRepository>()).call(
        saleItemId: saleItemId,
        quantity: quantity,
        qtyCarton: qtyCarton,
        qtyPack: qtyPack,
        qtyStrip: qtyStrip,
        qtyPill: qtyPill,
        refundAmount: refundAmount,
        settlementMethod: settlementMethod,
        paymentMethod: paymentMethod,
        walletId: walletId,
        reason: reason,
      );
      state = const ReturnsState(successMessage: 'تم تسجيل المرتجع بنجاح');
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: 'تعذر تسجيل المرتجع');
      return false;
    }
  }

  Future<bool> submitVendorReturn({
    required int purchaseItemId,
    required int quantity,
    required int qtyCarton,
    required int qtyPack,
    required int qtyStrip,
    required int qtyPill,
    required double refundAmount,
    required String settlementMethod,
    required String paymentMethod,
    int? walletId,
    String? reason,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true, clearSuccess: true);
    try {
      final processedBy = ref.read(authNotifierProvider).user?.id;
      await CreateVendorReturnUseCase(sl<ReturnsRepository>()).call(
        purchaseItemId: purchaseItemId,
        quantity: quantity,
        qtyCarton: qtyCarton,
        qtyPack: qtyPack,
        qtyStrip: qtyStrip,
        qtyPill: qtyPill,
        refundAmount: refundAmount,
        settlementMethod: settlementMethod,
        paymentMethod: paymentMethod,
        walletId: walletId,
        reason: reason,
      );
      state = const ReturnsState(successMessage: 'تم تسجيل مرتجع المورد بنجاح');
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: 'تعذر تسجيل مرتجع المورد');
      return false;
    }
  }

  void reset() => state = const ReturnsState();
}

final returnsNotifierProvider =
    AutoDisposeNotifierProvider<ReturnsNotifier, ReturnsState>(ReturnsNotifier.new);
