import '../../domain/entities/invoice_entity.dart';
import '../../domain/repositories/invoices_repository.dart';
import '../datasources/invoices_datasource.dart';

class InvoicesRepositoryImpl implements InvoicesRepository {
  final InvoicesDataSource _dataSource;

  InvoicesRepositoryImpl(this._dataSource);

  @override
  Future<List<InvoiceEntity>> searchAllInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return _dataSource.searchAllInvoices(query: query, fromDate: fromDate, toDate: toDate);
  }

  @override
  Future<List<InvoiceEntity>> searchSalesInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return _dataSource.searchSalesInvoices(query: query, fromDate: fromDate, toDate: toDate);
  }

  @override
  Future<List<InvoiceEntity>> searchPurchaseInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
    bool onlyUnpaid = false,
    int? supplierId,
  }) async {
    final list = await _dataSource.searchPurchaseInvoices(
      query: query,
      fromDate: fromDate,
      toDate: toDate,
    );
    var filtered = list;
    if (supplierId != null) {
      filtered = filtered.where((i) => i.partyName == supplierId.toString()).toList();
    }
    if (onlyUnpaid) {
      filtered = filtered.where((i) => (i.paidAmount ?? 0) < i.totalAmount).toList();
    }
    return filtered;
  }

  @override
  Future<List<InvoiceEntity>> searchReturnInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return _dataSource.searchReturnInvoices(query: query, fromDate: fromDate, toDate: toDate);
  }

  @override
  Future<List<InvoiceEntity>> searchExpenseInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return _dataSource.searchExpenseInvoices(query: query, fromDate: fromDate, toDate: toDate);
  }
}
