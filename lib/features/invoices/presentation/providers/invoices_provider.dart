import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/repositories/invoices_repository.dart';

class InvoicesState {
  final bool isLoading;
  final List<InvoiceEntity> allInvoices;
  final List<InvoiceEntity> salesInvoices;
  final List<InvoiceEntity> purchaseInvoices;
  final List<InvoiceEntity> returnInvoices;
  final List<InvoiceEntity> expenseInvoices;
  final String? errorMessage;
  
  // Search Filters
  final String searchQuery;
  final DateTime? fromDate;
  final DateTime? toDate;

  InvoicesState({
    this.isLoading = false,
    this.allInvoices = const [],
    this.salesInvoices = const [],
    this.purchaseInvoices = const [],
    this.returnInvoices = const [],
    this.expenseInvoices = const [],
    this.errorMessage,
    this.searchQuery = '',
    this.fromDate,
    this.toDate,
  });

  InvoicesState copyWith({
    bool? isLoading,
    List<InvoiceEntity>? allInvoices,
    List<InvoiceEntity>? salesInvoices,
    List<InvoiceEntity>? purchaseInvoices,
    List<InvoiceEntity>? returnInvoices,
    List<InvoiceEntity>? expenseInvoices,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
  }) {
    return InvoicesState(
      isLoading: isLoading ?? this.isLoading,
      allInvoices: allInvoices ?? this.allInvoices,
      salesInvoices: salesInvoices ?? this.salesInvoices,
      purchaseInvoices: purchaseInvoices ?? this.purchaseInvoices,
      returnInvoices: returnInvoices ?? this.returnInvoices,
      expenseInvoices: expenseInvoices ?? this.expenseInvoices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }
}

class InvoicesNotifier extends AutoDisposeNotifier<InvoicesState> {
  late InvoicesRepository _repository;

  @override
  InvoicesState build() {
    _repository = sl<InvoicesRepository>();
    Future.microtask(loadInvoices);
    return InvoicesState();
  }

  Future<void> loadInvoices() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final all = await _repository.searchAllInvoices(
        query: state.searchQuery,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      final sales = await _repository.searchSalesInvoices(
        query: state.searchQuery,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      final purchases = await _repository.searchPurchaseInvoices(
        query: state.searchQuery,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      final returns = await _repository.searchReturnInvoices(
        query: state.searchQuery,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      final expenses = await _repository.searchExpenseInvoices(
        query: state.searchQuery,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      
      state = state.copyWith(
        isLoading: false,
        allInvoices: all,
        salesInvoices: sales,
        purchaseInvoices: purchases,
        returnInvoices: returns,
        expenseInvoices: expenses,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر جلب الفواتير: $e');
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadInvoices();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      fromDate: from,
      clearFromDate: from == null,
      toDate: to,
      clearToDate: to == null,
    );
    loadInvoices();
  }
}

final invoicesProvider = AutoDisposeNotifierProvider<InvoicesNotifier, InvoicesState>(InvoicesNotifier.new);
