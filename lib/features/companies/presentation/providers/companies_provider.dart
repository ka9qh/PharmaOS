import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/companies_entity.dart';
import '../../domain/repositories/companies_repository.dart';
import '../../domain/usecases/companies_usecase.dart';

class CompaniesState {
  final bool isLoading;
  final List<CompanyEntity> items;
  final String? errorMessage;
  final String? successMessage;

  const CompaniesState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
    this.successMessage,
  });

  CompaniesState copyWith({
    bool? isLoading,
    List<CompanyEntity>? items,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CompaniesState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class CompaniesNotifier extends AutoDisposeNotifier<CompaniesState> {
  @override
  CompaniesState build() {
    Future.microtask(loadAll);
    return const CompaniesState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final list = await ListCompaniesUseCase(sl<CompaniesRepository>()).call();
      state = state.copyWith(isLoading: false, items: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل الشركات');
    }
  }

  Future<bool> add(String name) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await CreateCompanyUseCase(sl<CompaniesRepository>()).call(name);
      state = state.copyWith(successMessage: 'تمت الإضافة بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إضافة الشركة (قد يكون الاسم مكررًا)');
      return false;
    }
  }

  Future<bool> updateCompany(int id, String newName) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await UpdateCompanyUseCase(sl<CompaniesRepository>()).call(id, newName);
      state = state.copyWith(successMessage: 'تم تعديل الشركة بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تعديل بيانات الشركة');
      return false;
    }
  }

  Future<bool> deleteCompany(int id) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await ArchiveCompanyUseCase(sl<CompaniesRepository>()).call(id);
      state = state.copyWith(successMessage: 'تمت أرشفة الشركة بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حذف الشركة');
      return false;
    }
  }
}

final companiesNotifierProvider =
    AutoDisposeNotifierProvider<CompaniesNotifier, CompaniesState>(CompaniesNotifier.new);
