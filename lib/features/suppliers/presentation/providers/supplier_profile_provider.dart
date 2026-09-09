import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../purchases/domain/entities/purchases_entity.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../../core/entities/ledger_entry_entity.dart';
import '../../domain/repositories/suppliers_repository.dart';
import '../../domain/usecases/suppliers_usecase.dart';
import '../../data/datasources/supplier_ledger_datasource.dart';

class SupplierProfileState {
  final bool isLoading;
  final List<PurchaseEntity> purchases;
  final List<MedicineEntity> medicines;
  final List<LedgerEntryEntity> ledgerEntries;
  final String? errorMessage;

  const SupplierProfileState({
    this.isLoading = true,
    this.purchases = const [],
    this.medicines = const [],
    this.ledgerEntries = const [],
    this.errorMessage,
  });

  SupplierProfileState copyWith({
    bool? isLoading,
    List<PurchaseEntity>? purchases,
    List<MedicineEntity>? medicines,
    List<LedgerEntryEntity>? ledgerEntries,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupplierProfileState(
      isLoading: isLoading ?? this.isLoading,
      purchases: purchases ?? this.purchases,
      medicines: medicines ?? this.medicines,
      ledgerEntries: ledgerEntries ?? this.ledgerEntries,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SupplierProfileNotifier extends AutoDisposeFamilyNotifier<SupplierProfileState, int> {
  @override
  SupplierProfileState build(int arg) {
    Future.microtask(() => loadProfileData(arg));
    return const SupplierProfileState();
  }

  Future<void> loadProfileData(int supplierId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = sl<SuppliersRepository>();
      final purchases = await GetSupplierPurchasesUseCase(repo).call(supplierId);
      final medicines = await GetSupplierMedicinesUseCase(repo).call(supplierId);
      
      final ledgerSource = sl<SupplierLedgerDataSource>();
      final ledgerEntries = await ledgerSource.getSupplierLedger(supplierId);

      state = state.copyWith(
        isLoading: false,
        purchases: purchases,
        medicines: medicines,
        ledgerEntries: ledgerEntries,
      );
    } catch (e, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل بيانات المورد: ${e.toString()}',
      );
    }
  }
}

final supplierProfileProvider = AutoDisposeNotifierProviderFamily<SupplierProfileNotifier, SupplierProfileState, int>(
  SupplierProfileNotifier.new,
);
