import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/medicines_entity.dart';
import '../../domain/repositories/medicines_repository.dart';
import '../../domain/usecases/medicines_usecase.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MedicinesState {
  final bool isLoading;
  final List<MedicineEntity> items;
  final String? errorMessage;
  final String searchQuery;

  const MedicinesState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
    this.searchQuery = '',
  });

  MedicinesState copyWith({
    bool? isLoading,
    List<MedicineEntity>? items,
    String? errorMessage,
    String? searchQuery,
    bool clearError = false,
  }) {
    return MedicinesState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class MedicinesNotifier extends AutoDisposeNotifier<MedicinesState> {
  @override
  MedicinesState build() {
    Future.microtask(loadAll);
    return const MedicinesState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await ListMedicinesUseCase(sl<MedicinesRepository>())
          .call(searchQuery: state.searchQuery);
      state = state.copyWith(isLoading: false, items: list);
    } catch (e, st) {
      debugPrint('Error in MedicinesNotifier.loadAll: $e\n$st');
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل قائمة الأدوية: $e');
    }
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
    loadAll();
  }

  Future<bool> addMedicine({
    required String nameAr,
    String? nameEn,
    String? nameScientific,
    int? categoryId,
    int? companyId,
    int? supplierId,
    required String unit,
    required double purchasePrice,
    required double sellingPrice,
    int? qtyPerPack,
    int? qtyPerStrip,
    int? qtyPerCarton,
    double? stripPurchasePrice,
    double? stripSellingPrice,
    double? packPurchasePrice,
    double? packSellingPrice,
    double? cartonPurchasePrice,
    double? cartonSellingPrice,
    required int reorderLevel,
    String? reserveField1,
    String? reserveField2,
    String? reserveField3,
    int? medicineType,
  }) async {
    try {
      await CreateMedicineUseCase(sl<MedicinesRepository>()).call(
        nameAr: nameAr,
        nameEn: nameEn,
        nameScientific: nameScientific,
        categoryId: categoryId,
        companyId: companyId,
        supplierId: supplierId,
        unit: unit,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        qtyPerPack: qtyPerPack,
        qtyPerStrip: qtyPerStrip,
        qtyPerCarton: qtyPerCarton,
        stripPurchasePrice: stripPurchasePrice,
        stripSellingPrice: stripSellingPrice,
        packPurchasePrice: packPurchasePrice,
        packSellingPrice: packSellingPrice,
        cartonPurchasePrice: cartonPurchasePrice,
        cartonSellingPrice: cartonSellingPrice,
        reorderLevel: reorderLevel,
        reserveField1: reserveField1,
        reserveField2: reserveField2,
        reserveField3: reserveField3,
        medicineType: medicineType,
      );
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إضافة الدواء، تحقق من البيانات المدخلة');
      return false;
    }
  }

  /// تعديل دواء موجود - جديدة (لم تكن هناك أي طريقة لتعديل دواء بعد إنشائه).
  Future<bool> updateMedicine(MedicineEntity medicine) async {
    try {
      final currentUserId = ref.read(authNotifierProvider).user?.id;
      await UpdateMedicineUseCase(sl<MedicinesRepository>())
          .call(medicine, changedByUserId: currentUserId);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حفظ التعديلات، تحقق من البيانات المدخلة');
      return false;
    }
  }

  Future<bool> deleteMedicine(int id) async {
    try {
      final currentUserId = ref.read(authNotifierProvider).user?.id;
      await sl<MedicinesRepository>().archive(id, changedByUserId: currentUserId);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حذف الدواء');
      return false;
    }
  }

  Future<int> autoCleanDuplicates() async {
    try {
      final mergedCount = await AutoCleanDuplicatesUseCase(sl<MedicinesRepository>()).call();
      if (mergedCount > 0) {
        await loadAll();
      }
      return mergedCount;
    } catch (e) {
      state = state.copyWith(errorMessage: 'حدث خطأ أثناء دمج التكرارات: $e');
      return 0;
    }
  }
}

final medicinesNotifierProvider =
    AutoDisposeNotifierProvider<MedicinesNotifier, MedicinesState>(MedicinesNotifier.new);

