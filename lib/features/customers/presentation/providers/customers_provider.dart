import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/customers_entity.dart';
import '../../domain/repositories/customers_repository.dart';
import '../../domain/usecases/customers_usecase.dart';

class CustomersState {
  final bool isLoading;
  final List<CustomerEntity> items;
  final List<CustomerBalance> balances;
  final String? errorMessage;
  final String? successMessage;

  const CustomersState({
    this.isLoading = false,
    this.items = const [],
    this.balances = const [],
    this.errorMessage,
    this.successMessage,
  });

  CustomersState copyWith({
    bool? isLoading,
    List<CustomerEntity>? items,
    List<CustomerBalance>? balances,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CustomersState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      balances: balances ?? this.balances,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  CustomerBalance balanceFor(int customerId) {
    return balances.firstWhere(
      (b) => b.customerId == customerId,
      orElse: () => CustomerBalance(
        customerId: customerId,
        customerName: '',
        totalCredit: 0.0,
        totalPaid: 0.0,
      ),
    );
  }
}

class CustomersNotifier extends AutoDisposeNotifier<CustomersState> {
  @override
  CustomersState build() {
    Future.microtask(loadAll);
    return const CustomersState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final repo = sl<CustomersRepository>();
      final items = await ListCustomersUseCase(repo).call();
      final balances = await GetCustomerBalancesUseCase(repo).call();
      state = state.copyWith(isLoading: false, items: items, balances: balances);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل العملاء');
    }
  }

  Future<bool> add({required String name, String? phone, String? notes}) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await CreateCustomerUseCase(sl<CustomersRepository>()).call(name: name, phone: phone, notes: notes);
      state = state.copyWith(successMessage: 'تمت إضافة العميل بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إضافة العميل (قد يكون الاسم مكررًا)');
      return false;
    }
  }

  Future<bool> updateCustomer(int id, String newName, String? newPhone, String? newNotes) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await UpdateCustomerUseCase(sl<CustomersRepository>()).call(id, newName, newPhone, newNotes);
      state = state.copyWith(successMessage: 'تم تعديل بيانات العميل بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تعديل بيانات العميل');
      return false;
    }
  }

  Future<bool> deleteCustomer(int id) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await ArchiveCustomerUseCase(sl<CustomersRepository>()).call(id);
      state = state.copyWith(successMessage: 'تمت أرشفة العميل بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حذف العميل');
      return false;
    }
  }

  Future<bool> recordPayment({required int customerId, required double amount, String? notes}) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      final recordedBy = ref.read(authNotifierProvider).user?.id;
      await RecordCustomerPaymentUseCase(sl<CustomersRepository>()).call(
        customerId: customerId,
        amount: amount,
        notes: notes,
        recordedBy: recordedBy,
      );
      state = state.copyWith(successMessage: 'تم تسجيل التسديد بنجاح');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تسجيل التسديد');
      return false;
    }
  }
}

final customersNotifierProvider =
    AutoDisposeNotifierProvider<CustomersNotifier, CustomersState>(CustomersNotifier.new);
