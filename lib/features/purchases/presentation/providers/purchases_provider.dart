import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/purchases_entity.dart';
import '../../domain/repositories/purchases_repository.dart';
import '../../domain/usecases/purchases_usecase.dart';

class PurchasesState {
  final bool isLoading;
  final List<PurchaseEntity> items;
  final String? errorMessage;

  const PurchasesState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
  });

  PurchasesState copyWith({
    bool? isLoading,
    List<PurchaseEntity>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PurchasesState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PurchasesNotifier extends AutoDisposeNotifier<PurchasesState> {
  @override
  PurchasesState build() {
    Future.microtask(loadAll);
    return const PurchasesState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await ListPurchasesUseCase(sl<PurchasesRepository>()).call();
      state = state.copyWith(isLoading: false, items: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل المشتريات');
    }
  }

  Future<bool> createPurchase({
    required int supplierId,
    String? supplierInvoiceRef,
    required List<PurchaseLineInput> items,
    required double paidAmount,
    String? invoiceImagePath,
  }) async {
    try {
      await CreatePurchaseUseCase(sl<PurchasesRepository>()).call(
        supplierId: supplierId,
        supplierInvoiceRef: supplierInvoiceRef,
        items: items,
        paidAmount: paidAmount,
        invoiceImagePath: invoiceImagePath,
      );
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حفظ فاتورة الشراء');
      return false;
    }
  }
}

final purchasesNotifierProvider =
    AutoDisposeNotifierProvider<PurchasesNotifier, PurchasesState>(PurchasesNotifier.new);
