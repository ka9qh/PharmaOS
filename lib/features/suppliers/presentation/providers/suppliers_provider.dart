import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/suppliers_entity.dart';
import '../../domain/repositories/suppliers_repository.dart';
import '../../domain/usecases/suppliers_usecase.dart';

class SuppliersState {
  final bool isLoading;
  final List<SupplierEntity> items;
  final String? errorMessage;
  final String? successMessage;

  const SuppliersState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
    this.successMessage,
  });

  SuppliersState copyWith({
    bool? isLoading,
    List<SupplierEntity>? items,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return SuppliersState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class SuppliersNotifier extends AutoDisposeNotifier<SuppliersState> {
  @override
  SuppliersState build() {
    Future.microtask(loadAll);
    return const SuppliersState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final list = await ListSuppliersUseCase(sl<SuppliersRepository>()).call();
      state = state.copyWith(isLoading: false, items: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل الموردين');
    }
  }

  Future<bool> add({required String name, String? contactInfo, String? notes}) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await CreateSupplierUseCase(sl<SuppliersRepository>())
          .call(name: name, contactInfo: contactInfo, notes: notes);
      state = state.copyWith(successMessage: 'تمت إضافة المورد بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إضافة المورد (قد يكون الاسم مكررًا)');
      return false;
    }
  }

  Future<bool> updateSupplier(int id, String newName) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await UpdateSupplierUseCase(sl<SuppliersRepository>()).call(id, newName);
      state = state.copyWith(successMessage: 'تم تعديل المورد بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تعديل بيانات المورد');
      return false;
    }
  }

  Future<bool> deleteSupplier(int id) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await ArchiveSupplierUseCase(sl<SuppliersRepository>()).call(id);
      state = state.copyWith(successMessage: 'تمت أرشفة المورد بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حذف المورد');
      return false;
    }
  }
}

final suppliersNotifierProvider =
    AutoDisposeNotifierProvider<SuppliersNotifier, SuppliersState>(SuppliersNotifier.new);
