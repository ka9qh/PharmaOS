import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/expenses_entity.dart';
import '../../domain/repositories/expenses_repository.dart';

enum ExpenseFilterMode {
  all,
  today,
  singleDate,
  monthYear,
  fullYear,
  dateRange,
}

class ExpensesState {
  final bool isLoading;
  final List<ExpenseEntity> items;
  final double totalAmount;
  final ExpenseFilterMode filterMode;
  final DateTime? selectedDate;
  final int selectedYear;
  final int selectedMonth;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? errorMessage;
  final String searchQuery;

  ExpensesState({
    this.isLoading = false,
    this.items = const [],
    this.totalAmount = 0,
    this.filterMode = ExpenseFilterMode.monthYear,
    DateTime? selectedDate,
    int? selectedYear,
    int? selectedMonth,
    this.fromDate,
    this.toDate,
    this.errorMessage,
    this.searchQuery = '',
  })  : selectedDate = selectedDate ?? DateTime.now(),
        selectedYear = selectedYear ?? DateTime.now().year,
        selectedMonth = selectedMonth ?? DateTime.now().month;

  List<ExpenseEntity> get todayItems {
    final now = DateTime.now();
    return items.where((e) =>
        e.createdAt.year == now.year &&
        e.createdAt.month == now.month &&
        e.createdAt.day == now.day).toList();
  }

  double get todayTotal => todayItems.fold(0.0, (sum, e) => sum + e.amount);

  ExpensesState copyWith({
    bool? isLoading,
    List<ExpenseEntity>? items,
    double? totalAmount,
    ExpenseFilterMode? filterMode,
    DateTime? selectedDate,
    int? selectedYear,
    int? selectedMonth,
    DateTime? fromDate,
    DateTime? toDate,
    String? errorMessage,
    String? searchQuery,
    bool clearError = false,
  }) {
    return ExpensesState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      filterMode: filterMode ?? this.filterMode,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedYear: selectedYear ?? this.selectedYear,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ExpensesNotifier extends AutoDisposeNotifier<ExpensesState> {
  @override
  ExpensesState build() {
    Future.microtask(loadExpenses);
    return ExpensesState();
  }

  Future<void> loadExpenses() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = sl<ExpensesRepository>();
      List<ExpenseEntity> list;

      switch (state.filterMode) {
        case ExpenseFilterMode.all:
          list = await repo.listAll(query: state.searchQuery);
          break;
        case ExpenseFilterMode.today:
          final today = DateTime.now();
          list = await repo.listByDate(today, query: state.searchQuery);
          break;
        case ExpenseFilterMode.singleDate:
          final d = state.selectedDate ?? DateTime.now();
          list = await repo.listByDate(d, query: state.searchQuery);
          break;
        case ExpenseFilterMode.fullYear:
          list = await repo.listByYear(state.selectedYear, query: state.searchQuery);
          break;
        case ExpenseFilterMode.dateRange:
          final from = state.fromDate ?? DateTime.now().subtract(const Duration(days: 30));
          final to = state.toDate ?? DateTime.now();
          list = await repo.listByDateRange(from, to, query: state.searchQuery);
          break;
        case ExpenseFilterMode.monthYear:
          list = await repo.listByMonthAndYear(
            state.selectedYear,
            state.selectedMonth,
            query: state.searchQuery,
          );
          break;
      }

      final total = list.fold<double>(0, (sum, e) => sum + e.amount);
      state = state.copyWith(isLoading: false, items: list, totalAmount: total);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل المصاريف: $e');
    }
  }

  void showAll() {
    state = state.copyWith(filterMode: ExpenseFilterMode.all);
    loadExpenses();
  }

  void setToday() {
    state = state.copyWith(filterMode: ExpenseFilterMode.today);
    loadExpenses();
  }

  void setSingleDate(DateTime date) {
    state = state.copyWith(
      filterMode: ExpenseFilterMode.singleDate,
      selectedDate: date,
    );
    loadExpenses();
  }

  void setPeriod(int year, int month) {
    state = state.copyWith(
      filterMode: ExpenseFilterMode.monthYear,
      selectedYear: year,
      selectedMonth: month,
    );
    loadExpenses();
  }

  void setFullYear(int year) {
    state = state.copyWith(
      filterMode: ExpenseFilterMode.fullYear,
      selectedYear: year,
    );
    loadExpenses();
  }

  void setDateRange(DateTime from, DateTime to) {
    state = state.copyWith(
      filterMode: ExpenseFilterMode.dateRange,
      fromDate: from,
      toDate: to,
    );
    loadExpenses();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadExpenses();
  }

  Future<bool> add({
    required String category,
    required double amount,
    String? notes,
    int? workerId,
    String? customWorkerName,
    String paymentMethod = 'نقدي',
    int? walletId,
    int? recordedBy,
  }) async {
    try {
      final repo = sl<ExpensesRepository>();
      await repo.create(
        category: category,
        amount: amount,
        notes: notes,
        workerId: workerId,
        customWorkerName: customWorkerName,
        paymentMethod: paymentMethod,
        walletId: walletId,
        recordedBy: recordedBy,
      );
      await loadExpenses();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تسجيل المصروف: $e');
      return false;
    }
  }
}

final expensesNotifierProvider =
    AutoDisposeNotifierProvider<ExpensesNotifier, ExpensesState>(ExpensesNotifier.new);

