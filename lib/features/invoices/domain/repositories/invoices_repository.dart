import '../entities/invoice_entity.dart';

abstract class InvoicesRepository {
  Future<List<InvoiceEntity>> searchAllInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<InvoiceEntity>> searchSalesInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<InvoiceEntity>> searchPurchaseInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
    bool onlyUnpaid = false,
    int? supplierId,
  });

  Future<List<InvoiceEntity>> searchReturnInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<InvoiceEntity>> searchExpenseInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  });
}
