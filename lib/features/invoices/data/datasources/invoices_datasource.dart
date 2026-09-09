import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../domain/entities/invoice_entity.dart';

abstract class InvoicesDataSource {
  Future<List<InvoiceEntity>> searchSalesInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<InvoiceEntity>> searchPurchaseInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
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

  Future<List<InvoiceEntity>> searchAllInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  });
}

class InvoicesDataSourceImpl implements InvoicesDataSource {
  final AppDatabase _db;
  InvoicesDataSourceImpl(this._db);

  @override
  Future<List<InvoiceEntity>> searchSalesInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final select = _db.select(_db.sales).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(_db.sales.customerId)),
    ])..orderBy([OrderingTerm.desc(_db.sales.createdAt)]);

    final rows = await select.get();
    final List<InvoiceEntity> list = [];

    for (var row in rows) {
      final sale = row.readTable(_db.sales);
      final customer = row.readTableOrNull(_db.customers);

      if (fromDate != null && sale.createdAt.isBefore(fromDate)) continue;
      if (toDate != null && sale.createdAt.isAfter(toDate.add(const Duration(days: 1)))) continue;

      final itemRows = await (_db.select(_db.saleItems).join([
        innerJoin(_db.medicines, _db.medicines.id.equalsExp(_db.saleItems.medicineId)),
        leftOuterJoin(_db.batches, _db.batches.id.equalsExp(_db.saleItems.batchId)),
      ])..where(_db.saleItems.saleId.equals(sale.id))).get();

      final supplierRows = await _db.select(_db.suppliers).get();
      final supplierMap = {for (final s in supplierRows) s.id: s.name};

      final items = await Future.wait(itemRows.map((r) async {
        final item = r.readTable(_db.saleItems);
        final medicine = r.readTable(_db.medicines);
        final batch = r.readTableOrNull(_db.batches);

        String? itemSupplier = medicine.supplierId != null ? supplierMap[medicine.supplierId] : null;
        if (batch != null) {
          final piRow = await (_db.select(_db.purchaseItems).join([
            innerJoin(_db.purchases, _db.purchases.id.equalsExp(_db.purchaseItems.purchaseId)),
            leftOuterJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchases.supplierId)),
          ])..where(_db.purchaseItems.batchId.equals(batch.id))).getSingleOrNull();
          if (piRow != null) {
            final s = piRow.readTableOrNull(_db.suppliers);
            if (s != null) itemSupplier = s.name;
          }
        }

        final formattedQty = UnitConverter.formatQuantity(
          totalPills: item.quantity,
          qtyPerCarton: medicine.qtyPerCarton,
          qtyPerPack: medicine.qtyPerPack,
          qtyPerStrip: medicine.qtyPerStrip,
          medicineType: medicine.medicineType,
        );

        return InvoiceItemEntity(
          id: item.id,
          medicineId: medicine.id,
          medicineName: medicine.nameAr,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          subtotal: item.subtotal,
          unitName: item.unitName ?? 'حبة',
          conversionFactor: item.conversionFactor,
          selectedQuantity: item.selectedQuantity ?? item.quantity,
          formattedQuantity: formattedQty,
          medicineType: medicine.medicineType,
          qtyPerCarton: medicine.qtyPerCarton ?? 1,
          qtyPerPack: medicine.qtyPerPack ?? 1,
          qtyPerStrip: medicine.qtyPerStrip ?? 1,
          purchasePrice: medicine.purchasePrice,
          sellingPrice: medicine.sellingPrice,
          batchNumber: batch?.batchNumber,
          expiryDate: batch?.expiryDate,
          supplierName: itemSupplier,
          stripPurchasePrice: medicine.stripPurchasePrice,
          stripSellingPrice: medicine.stripSellingPrice,
          packPurchasePrice: medicine.packPurchasePrice,
          packSellingPrice: medicine.packSellingPrice,
          cartonPurchasePrice: medicine.cartonPurchasePrice,
          cartonSellingPrice: medicine.cartonSellingPrice,
        );
      }));

      final party = customer?.name ?? 'عميل نقدي';
      final invoiceName = sale.paymentMethod == 'آجل' ? 'فاتورة آجل - $party' : 'فاتورة بيع نقدي';

      // فحص المرتجعات المرتبطة بفاتورة المبيعات
      final returnRows = await (_db.select(_db.returns)..where((r) => r.saleId.equals(sale.id))).get();
      List<InvoiceReturnRefEntity> linkedReturns = [];
      String saleStatus = sale.status;
      if (returnRows.isNotEmpty) {
        final totalReturned = returnRows.fold<double>(0.0, (sum, r) => sum + r.totalAmount);
        saleStatus = totalReturned >= sale.totalAmount ? 'returned' : 'partially_returned';

        for (final r in returnRows) {
          final rItems = await (_db.select(_db.returnItems).join([
            innerJoin(_db.medicines, _db.medicines.id.equalsExp(_db.returnItems.medicineId)),
          ])..where(_db.returnItems.returnId.equals(r.id))).get();

          final parsedItems = rItems.map((ri) {
            final retItem = ri.readTable(_db.returnItems);
            final med = ri.readTable(_db.medicines);
            final formattedQty = UnitConverter.formatQuantity(
              totalPills: retItem.quantity,
              qtyPerCarton: med.qtyPerCarton,
              qtyPerPack: med.qtyPerPack,
              qtyPerStrip: med.qtyPerStrip,
              medicineType: med.medicineType,
            );
            return InvoiceItemEntity(
              id: retItem.id,
              medicineId: med.id,
              medicineName: med.nameAr,
              quantity: retItem.quantity,
              unitPrice: retItem.unitPrice,
              subtotal: retItem.subtotal,
              unitName: 'حبة',
              conversionFactor: 1,
              selectedQuantity: retItem.quantity,
              qtyCarton: retItem.qtyCarton,
              qtyPack: retItem.qtyPack,
              qtyStrip: retItem.qtyStrip,
              qtyPill: retItem.qtyPill,
              formattedQuantity: formattedQty,
              medicineType: med.medicineType,
            );
          }).toList();

          linkedReturns.add(InvoiceReturnRefEntity(
            returnId: r.id,
            returnNumber: 'RET-C-${r.id.toString().padLeft(4, '0')}',
            returnDate: r.createdAt,
            totalAmount: r.totalAmount,
            settlementMethod: r.settlementMethod,
            reason: r.reason,
            returnType: 'CUSTOMER_RETURN',
            items: parsedItems,
          ));
        }
      }

      list.add(InvoiceEntity(
        id: sale.id,
        invoiceNumber: sale.invoiceNumber,
        invoiceName: invoiceName,
        date: sale.createdAt,
        totalAmount: sale.totalAmount,
        discount: sale.discount,
        paymentMethod: sale.paymentMethod,
        type: 'SALE',
        partyName: party,
        status: saleStatus,
        items: items,
        linkedReturns: linkedReturns,
      ));
    }

    return _applyQueryFilter(list, query);
  }

  @override
  Future<List<InvoiceEntity>> searchPurchaseInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final select = _db.select(_db.purchases).join([
      leftOuterJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchases.supplierId)),
    ])..orderBy([OrderingTerm.desc(_db.purchases.createdAt)]);

    final rows = await select.get();
    final List<InvoiceEntity> list = [];

    for (var row in rows) {
      final purchase = row.readTable(_db.purchases);
      final supplier = row.readTableOrNull(_db.suppliers);

      if (fromDate != null && purchase.createdAt.isBefore(fromDate)) continue;
      if (toDate != null && purchase.createdAt.isAfter(toDate.add(const Duration(days: 1)))) continue;

      final itemRows = await (_db.select(_db.purchaseItems).join([
        innerJoin(_db.medicines, _db.medicines.id.equalsExp(_db.purchaseItems.medicineId)),
        leftOuterJoin(_db.batches, _db.batches.id.equalsExp(_db.purchaseItems.batchId)),
      ])..where(_db.purchaseItems.purchaseId.equals(purchase.id))).get();

      final items = itemRows.map((r) {
        final item = r.readTable(_db.purchaseItems);
        final medicine = r.readTable(_db.medicines);
        final batch = r.readTableOrNull(_db.batches);

        String formattedQty = UnitConverter.formatQuantity(
          totalPills: item.quantity,
          qtyPerCarton: medicine.qtyPerCarton,
          qtyPerPack: medicine.qtyPerPack,
          qtyPerStrip: medicine.qtyPerStrip,
          medicineType: medicine.medicineType,
        );

        // إذا كان هناك إدخال مباشر لمكونات الوحدات في سطر الشراء
        if (item.qtyCarton > 0 || item.qtyPack > 0 || item.qtyStrip > 0 || item.qtyPill > 0) {
          final List<String> parts = [];
          if (item.qtyCarton > 0) parts.add('${item.qtyCarton} كرتون');
          if (item.qtyPack > 0) parts.add('${item.qtyPack} باكت');
          if (item.qtyStrip > 0) parts.add('${item.qtyStrip} شريط');
          if (item.qtyPill > 0) parts.add('${item.qtyPill} حبة');
          if (parts.isNotEmpty) {
            formattedQty = '${parts.join(" و ")} (إجمالي: ${item.quantity} حبة)';
          }
        }

        String effectiveUnitName = item.unitName ?? 'حبة';
        int effectiveSelectedQty = item.selectedQuantity ?? item.quantity;
        if (item.unitName == null || item.unitName!.isEmpty) {
          if (item.qtyCarton > 0) {
            effectiveUnitName = 'كرتون';
            effectiveSelectedQty = item.qtyCarton;
          } else if (item.qtyPack > 0) {
            effectiveUnitName = 'باكت';
            effectiveSelectedQty = item.qtyPack;
          } else if (item.qtyStrip > 0) {
            effectiveUnitName = 'شريط';
            effectiveSelectedQty = item.qtyStrip;
          } else if (item.qtyPill > 0) {
            effectiveUnitName = 'حبة';
            effectiveSelectedQty = item.qtyPill;
          } else if (formattedQty.contains('باكت')) {
            effectiveUnitName = 'باكت';
            final pPerPack = (medicine.qtyPerPack ?? 1) * (medicine.qtyPerStrip ?? 1);
            if (pPerPack > 0) {
              effectiveSelectedQty = (item.quantity / pPerPack).round();
            }
          }
        }

        return InvoiceItemEntity(
          id: item.id,
          medicineId: medicine.id,
          medicineName: medicine.nameAr,
          quantity: item.quantity,
          unitPrice: item.unitCost,
          subtotal: item.subtotal,
          unitName: effectiveUnitName,
          conversionFactor: item.conversionFactor,
          selectedQuantity: effectiveSelectedQty,
          qtyCarton: item.qtyCarton,
          qtyPack: item.qtyPack,
          qtyStrip: item.qtyStrip,
          qtyPill: item.qtyPill,
          formattedQuantity: formattedQty,
          medicineType: medicine.medicineType,
          qtyPerCarton: medicine.qtyPerCarton ?? 1,
          qtyPerPack: medicine.qtyPerPack ?? 1,
          qtyPerStrip: medicine.qtyPerStrip ?? 1,
          purchasePrice: medicine.purchasePrice > 0 ? medicine.purchasePrice : item.unitCost,
          sellingPrice: medicine.sellingPrice,
          batchNumber: batch?.batchNumber,
          expiryDate: batch?.expiryDate,
          supplierName: supplier?.name ?? 'مورد عام',
          stripPurchasePrice: medicine.stripPurchasePrice,
          stripSellingPrice: medicine.stripSellingPrice,
          packPurchasePrice: medicine.packPurchasePrice,
          packSellingPrice: medicine.packSellingPrice,
          cartonPurchasePrice: medicine.cartonPurchasePrice,
          cartonSellingPrice: medicine.cartonSellingPrice,
        );
      }).toList();

      final party = supplier?.name ?? 'مورد عام';
      final invoiceName = purchase.supplierInvoiceRef != null && purchase.supplierInvoiceRef!.isNotEmpty
          ? 'فاتورة توريد: ${purchase.supplierInvoiceRef}'
          : 'فاتورة مشتريات: ${purchase.purchaseNumber}';

      // فحص ما إذا كانت فاتورة الشراء مسترجعة كلياً أو جزئياً
      final returnRows = await (_db.select(_db.returns)..where((r) => r.purchaseId.equals(purchase.id))).get();
      String purchaseStatus = 'completed';
      List<InvoiceReturnRefEntity> linkedReturns = [];
      if (returnRows.isNotEmpty) {
        final totalReturned = returnRows.fold<double>(0.0, (sum, r) => sum + r.totalAmount);
        purchaseStatus = totalReturned >= purchase.totalAmount ? 'returned' : 'partially_returned';

        for (final r in returnRows) {
          final rItems = await (_db.select(_db.returnItems).join([
            innerJoin(_db.medicines, _db.medicines.id.equalsExp(_db.returnItems.medicineId)),
          ])..where(_db.returnItems.returnId.equals(r.id))).get();

          final parsedItems = rItems.map((ri) {
            final retItem = ri.readTable(_db.returnItems);
            final med = ri.readTable(_db.medicines);
            final formattedQty = UnitConverter.formatQuantity(
              totalPills: retItem.quantity,
              qtyPerCarton: med.qtyPerCarton,
              qtyPerPack: med.qtyPerPack,
              qtyPerStrip: med.qtyPerStrip,
              medicineType: med.medicineType,
            );
            return InvoiceItemEntity(
              id: retItem.id,
              medicineId: med.id,
              medicineName: med.nameAr,
              quantity: retItem.quantity,
              unitPrice: retItem.unitPrice,
              subtotal: retItem.subtotal,
              unitName: 'حبة',
              conversionFactor: 1,
              selectedQuantity: retItem.quantity,
              qtyCarton: retItem.qtyCarton,
              qtyPack: retItem.qtyPack,
              qtyStrip: retItem.qtyStrip,
              qtyPill: retItem.qtyPill,
              formattedQuantity: formattedQty,
              medicineType: med.medicineType,
            );
          }).toList();

          linkedReturns.add(InvoiceReturnRefEntity(
            returnId: r.id,
            returnNumber: 'RET-V-${r.id.toString().padLeft(4, '0')}',
            returnDate: r.createdAt,
            totalAmount: r.totalAmount,
            settlementMethod: r.settlementMethod,
            reason: r.reason,
            returnType: 'VENDOR_RETURN',
            items: parsedItems,
          ));
        }
      }

      list.add(InvoiceEntity(
        id: purchase.id,
        invoiceNumber: purchase.purchaseNumber,
        invoiceName: invoiceName,
        date: purchase.createdAt,
        totalAmount: purchase.totalAmount,
        discount: 0,
        paymentMethod: purchase.paymentMethod,
        type: 'PURCHASE',
        partyName: party,
        paidAmount: purchase.paidAmount,
        status: purchaseStatus,
        items: items,
        linkedReturns: linkedReturns,
      ));
    }

    return _applyQueryFilter(list, query);
  }

  @override
  Future<List<InvoiceEntity>> searchReturnInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final select = _db.select(_db.returns).join([
      leftOuterJoin(_db.sales, _db.sales.id.equalsExp(_db.returns.saleId)),
      leftOuterJoin(_db.purchases, _db.purchases.id.equalsExp(_db.returns.purchaseId)),
    ])..orderBy([OrderingTerm.desc(_db.returns.createdAt)]);

    final rows = await select.get();
    final List<InvoiceEntity> list = [];

    for (var row in rows) {
      final ret = row.readTable(_db.returns);
      final sale = row.readTableOrNull(_db.sales);
      final purchase = row.readTableOrNull(_db.purchases);

      if (fromDate != null && ret.createdAt.isBefore(fromDate)) continue;
      if (toDate != null && ret.createdAt.isAfter(toDate.add(const Duration(days: 1)))) continue;

      final isCustomerReturn = ret.saleId != null;
      String party = 'عميل نقدي';
      String originalRef = '';

      if (isCustomerReturn && sale != null) {
        originalRef = sale.invoiceNumber;
        if (sale.customerId != null) {
          final customer = await (_db.select(_db.customers)..where((c) => c.id.equals(sale.customerId!))).getSingleOrNull();
          if (customer != null) party = customer.name;
        }
      } else if (purchase != null) {
        originalRef = purchase.purchaseNumber;
        final supplier = await (_db.select(_db.suppliers)..where((s) => s.id.equals(purchase.supplierId))).getSingleOrNull();
        party = supplier?.name ?? 'مورد عام';
      }

      // جلب عناصر المرتجع
      final itemRows = await (_db.select(_db.returnItems).join([
        innerJoin(_db.medicines, _db.medicines.id.equalsExp(_db.returnItems.medicineId)),
      ])..where(_db.returnItems.returnId.equals(ret.id))).get();

      final items = await Future.wait(itemRows.map((r) async {
        final item = r.readTable(_db.returnItems);
        final medicine = r.readTable(_db.medicines);

        BatchRow? batch;
        if (item.originalSaleItemId != null) {
          final sRow = await (_db.select(_db.saleItems).join([
            leftOuterJoin(_db.batches, _db.batches.id.equalsExp(_db.saleItems.batchId)),
          ])..where(_db.saleItems.id.equals(item.originalSaleItemId!))).getSingleOrNull();
          batch = sRow?.readTableOrNull(_db.batches);
        } else if (item.originalPurchaseItemId != null) {
          final pRow = await (_db.select(_db.purchaseItems).join([
            leftOuterJoin(_db.batches, _db.batches.id.equalsExp(_db.purchaseItems.batchId)),
          ])..where(_db.purchaseItems.id.equals(item.originalPurchaseItemId!))).getSingleOrNull();
          batch = pRow?.readTableOrNull(_db.batches);
        }

        batch ??= await (_db.select(_db.batches)
          ..where((b) => b.medicineId.equals(medicine.id))
          ..orderBy([(b) => OrderingTerm.desc(b.expiryDate)])
          ..limit(1)).getSingleOrNull();

        final formattedQty = UnitConverter.formatQuantity(
          totalPills: item.quantity,
          qtyPerCarton: medicine.qtyPerCarton,
          qtyPerPack: medicine.qtyPerPack,
          qtyPerStrip: medicine.qtyPerStrip,
          medicineType: medicine.medicineType,
        );

        return InvoiceItemEntity(
          id: item.id,
          medicineId: medicine.id,
          medicineName: medicine.nameAr,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          subtotal: item.subtotal,
          unitName: 'حبة',
          conversionFactor: 1,
          selectedQuantity: item.quantity,
          qtyCarton: item.qtyCarton,
          qtyPack: item.qtyPack,
          qtyStrip: item.qtyStrip,
          qtyPill: item.qtyPill,
          formattedQuantity: formattedQty,
          medicineType: medicine.medicineType,
          qtyPerCarton: medicine.qtyPerCarton ?? 1,
          qtyPerPack: medicine.qtyPerPack ?? 1,
          qtyPerStrip: medicine.qtyPerStrip ?? 1,
          purchasePrice: medicine.purchasePrice,
          sellingPrice: medicine.sellingPrice,
          batchNumber: batch?.batchNumber,
          expiryDate: batch?.expiryDate,
          supplierName: party,
          stripPurchasePrice: medicine.stripPurchasePrice,
          stripSellingPrice: medicine.stripSellingPrice,
          packPurchasePrice: medicine.packPurchasePrice,
          packSellingPrice: medicine.packSellingPrice,
          cartonPurchasePrice: medicine.cartonPurchasePrice,
          cartonSellingPrice: medicine.cartonSellingPrice,
        );
      }));

      final returnNumber = isCustomerReturn ? 'RET-C-${ret.id.toString().padLeft(4, '0')}' : 'RET-V-${ret.id.toString().padLeft(4, '0')}';
      final invoiceName = isCustomerReturn 
          ? 'مرتجع مبيعات (فاتورة $originalRef)' 
          : 'مرتجع مشتريات (فاتورة $originalRef)';

      double total = ret.totalAmount;
      if (total == 0 && items.isNotEmpty) {
        total = items.fold<double>(0, (sum, it) => sum + it.subtotal);
      }

      list.add(InvoiceEntity(
        id: ret.id,
        invoiceNumber: returnNumber,
        invoiceName: invoiceName,
        date: ret.createdAt,
        totalAmount: total,
        discount: 0,
        paymentMethod: ret.paymentMethod,
        type: isCustomerReturn ? 'CUSTOMER_RETURN' : 'VENDOR_RETURN',
        partyName: party,
        originalInvoiceRef: originalRef,
        originalInvoiceId: isCustomerReturn ? ret.saleId : ret.purchaseId,
        originalInvoiceNumber: originalRef,
        originalInvoiceType: isCustomerReturn ? 'SALE' : 'PURCHASE',
        reason: ret.reason,
        status: 'returned',
        items: items,
      ));
    }

    return _applyQueryFilter(list, query);
  }

  @override
  Future<List<InvoiceEntity>> searchExpenseInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final select = _db.select(_db.expenses).join([
      leftOuterJoin(_db.workers, _db.workers.id.equalsExp(_db.expenses.workerId)),
      leftOuterJoin(_db.wallets, _db.wallets.id.equalsExp(_db.expenses.walletId)),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.expenses.recordedBy)),
    ])..orderBy([OrderingTerm.desc(_db.expenses.createdAt)]);

    final rows = await select.get();
    final List<InvoiceEntity> list = [];

    for (var row in rows) {
      final expense = row.readTable(_db.expenses);
      final worker = row.readTableOrNull(_db.workers);
      final wallet = row.readTableOrNull(_db.wallets);
      final user = row.readTableOrNull(_db.users);

      if (fromDate != null && expense.createdAt.isBefore(fromDate)) continue;
      if (toDate != null && expense.createdAt.isAfter(toDate.add(const Duration(days: 1)))) continue;

      final recipient = (expense.customWorkerName != null && expense.customWorkerName!.trim().isNotEmpty)
          ? expense.customWorkerName!.trim()
          : (worker?.name ?? 'إدارة الصيدلية (مصروف عام)');

      final invoiceNum = 'EXP-${expense.id.toString().padLeft(4, '0')}';
      final invoiceName = 'سند صرف مصروف: ${expense.category}';

      final paymentDisplay = (expense.paymentMethod == 'محفظة' && wallet?.name != null)
          ? 'محفظة (${wallet!.name})'
          : expense.paymentMethod;

      final recorderName = user?.fullName ?? user?.username;

      final items = [
        InvoiceItemEntity(
          id: expense.id,
          medicineId: 0,
          medicineName: expense.category,
          quantity: 1,
          unitPrice: expense.amount,
          subtotal: expense.amount,
          unitName: 'بند صرف',
          conversionFactor: 1,
          selectedQuantity: 1,
          formattedQuantity: '1 بند',
        ),
      ];

      list.add(InvoiceEntity(
        id: expense.id,
        invoiceNumber: invoiceNum,
        invoiceName: invoiceName,
        date: expense.createdAt,
        totalAmount: expense.amount,
        discount: 0,
        paymentMethod: paymentDisplay,
        type: 'EXPENSE',
        partyName: recipient,
        reason: expense.notes,
        items: items,
        category: expense.category,
        workerName: expense.customWorkerName ?? worker?.name,
        recorderName: recorderName,
        walletName: wallet?.name,
        beneficiaryName: recipient,
      ));
    }

    return _applyQueryFilter(list, query);
  }

  @override
  Future<List<InvoiceEntity>> searchAllInvoices({
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final sales = await searchSalesInvoices(fromDate: fromDate, toDate: toDate);
    final purchases = await searchPurchaseInvoices(fromDate: fromDate, toDate: toDate);
    final returns = await searchReturnInvoices(fromDate: fromDate, toDate: toDate);
    final expenses = await searchExpenseInvoices(fromDate: fromDate, toDate: toDate);

    final all = [...sales, ...purchases, ...returns, ...expenses];
    all.sort((a, b) => b.date.compareTo(a.date));

    return _applyQueryFilter(all, query);
  }

  List<InvoiceEntity> _applyQueryFilter(List<InvoiceEntity> invoices, String? query) {
    if (query == null || query.trim().isEmpty) return invoices;
    final q = query.trim().toLowerCase();

    return invoices.where((inv) {
      final matchNum = inv.invoiceNumber.toLowerCase().contains(q);
      final matchName = inv.invoiceName != null && inv.invoiceName!.toLowerCase().contains(q);
      final matchParty = inv.partyName.toLowerCase().contains(q);
      final matchAmount = inv.totalAmount.toString().contains(q);
      final matchPayment = inv.paymentMethod.toLowerCase().contains(q);
      final matchRef = inv.originalInvoiceRef != null && inv.originalInvoiceRef!.toLowerCase().contains(q);
      final matchReason = inv.reason != null && inv.reason!.toLowerCase().contains(q);
      final matchMedicine = inv.items.any((item) => item.medicineName.toLowerCase().contains(q));

      return matchNum || matchName || matchParty || matchAmount || matchPayment || matchRef || matchReason || matchMedicine;
    }).toList();
  }
}

