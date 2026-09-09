// إدارة حالة ميزة التصنيفات - نفس نمط Notifier اليدوي المعتمد في auth_provider.dart
// (بديل موحّد لبقية النظام بدلاً من riverpod_generator - راجع docs/STATE_MANAGEMENT.md)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/categories_entity.dart';
import '../../domain/repositories/categories_repository.dart';
import '../../domain/usecases/categories_usecase.dart';

class CategoriesState {
  final bool isLoading;
  final List<CategoryEntity> items;
  final String? errorMessage;
  final String? successMessage;

  const CategoriesState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
    this.successMessage,
  });

  CategoriesState copyWith({
    bool? isLoading,
    List<CategoryEntity>? items,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CategoriesState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class CategoriesNotifier extends AutoDisposeNotifier<CategoriesState> {
  @override
  CategoriesState build() {
    Future.microtask(loadAll);
    return const CategoriesState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final list = await ListCategoriesUseCase(sl<CategoriesRepository>()).call();
      state = state.copyWith(isLoading: false, items: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل التصنيفات');
    }
  }

  Future<bool> add(String name) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await CreateCategoryUseCase(sl<CategoriesRepository>()).call(name);
      state = state.copyWith(successMessage: 'تمت الإضافة بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إضافة التصنيف (قد يكون الاسم مكررًا)');
      return false;
    }
  }

  Future<bool> updateCategory(int id, String newName) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await UpdateCategoryUseCase(sl<CategoriesRepository>()).call(id, newName);
      state = state.copyWith(successMessage: 'تم التعديل بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تعديل القسم');
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await ArchiveCategoryUseCase(sl<CategoriesRepository>()).call(id);
      state = state.copyWith(successMessage: 'تم أرشفة القسم (وحماية الأدوية المرتبطة)');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حذف القسم');
      return false;
    }
  }

  Future<bool> reorder(int oldIndex, int newIndex) async {
    // Reorder locally first for UI snap
    final currentList = List<CategoryEntity>.from(state.items);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = currentList.removeAt(oldIndex);
    currentList.insert(newIndex, item);
    
    state = state.copyWith(items: currentList);

    try {
      final ids = currentList.map((c) => c.id).toList();
      await UpdateCategoriesOrderUseCase(sl<CategoriesRepository>()).call(ids);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حفظ الترتيب الجديد');
      await loadAll(); // Revert on failure
      return false;
    }
  }
}

final categoriesNotifierProvider =
    AutoDisposeNotifierProvider<CategoriesNotifier, CategoriesState>(CategoriesNotifier.new);
