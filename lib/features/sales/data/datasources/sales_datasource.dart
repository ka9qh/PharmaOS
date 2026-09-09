// أهم ملف منطقي في المشروع حتى الآن: إنشاء فاتورة بيع كاملة بشكل ذرّي (Atomic)
//
// القاعدة: كل شيء داخل _db.transaction() - إذا فشل أي سطر (نقص مخزون)، يتراجع
// Drift تلقائيًا عن كل الكتابة (الفاتورة + خصم أي دفعات سبق خصمها لنفس الفاتورة).
// هذا يمنع تمامًا سيناريو "فاتورة محفوظة لكن المخزون لم يُخصم بشكل صحيح".
//
// منطق FEFO (First-Expire-First-Out): عند البيع، نخصم من الدفعة الأقرب انتهاءً أولًا.
// الدفعات بدون تاريخ انتهاء مسجّل تُعتبر الأخيرة في الأولوية (راجع docs/WORKFLOW.md).

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/sales_entity.dart';
import '../../../accounting/domain/repositories/general_ledger_repository.dart';
import '../../../accounting/domain/entities/accounting_entities.dart';

abstract class SalesDataSource {
  Future<SaleRow> createSaleTransactional({
    required List<CartLineInput> items,
    required double discount,
    required String paymentMethod,
    int? cashierId,
    int? customerId,
    int? doctorId,
    int? prescriptionId,
  });

  Future<double> getTodaySalesTotal();

  // ميزة تعليق الفواتير (Hold Invoices)
  Future<void> suspendSale({
    required List<CartLineInput> items,
    int? cashierId,
    int? customerId,
    String? referenceNote,
  });
  Future<List<HeldInvoiceRow>> getSuspendedSales();
  Future<void> deleteSuspendedSale(int id);
}

class SalesDataSourceImpl implements SalesDataSource {
  final AppDatabase _db;
  final GeneralLedgerRepository _glRepo;
  SalesDataSourceImpl(this._db, this._glRepo);

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<String> _generateInvoiceNumber() async {
    final now = DateTime.now();
    final todayCount = await (_db.select(_db.sales)
          ..where((s) => s.createdAt.isBiggerOrEqualValue(_startOfToday)))
        .get()
        .then((rows) => rows.length);

    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final seq = (todayCount + 1).toString().padLeft(4, '0');
    return 'INV-$datePart-$seq';
  }

  @override
  Future<SaleRow> createSaleTransactional({
    required List<CartLineInput> items,
    required double discount,
    required String paymentMethod,
    int? cashierId,
    int? customerId,
    int? doctorId,
    int? prescriptionId,
  }) async {
    if (items.isEmpty) {
      throw const FormatException('لا يمكن إنشاء فاتورة بيع فارغة بدون أصناف.');
    }
    
    if (discount < 0) {
      throw const FormatException('قيمة الخصم لا يمكن أن تكون سالبة.');
    }

    final saleResult = await _db.transaction(() async {
      final subtotal = items.fold<double>(
        0,
        (sum, item) {
          if (item.selectedQuantity <= 0 || item.quantity <= 0) {
            throw FormatException('الكمية للصنف ${item.medicineName} يجب أن تكون أكبر من صفر.');
          }
          if (item.unitPrice < 0) {
            throw FormatException('السعر للصنف ${item.medicineName} لا يمكن أن يكون سالباً.');
          }
          return sum + (item.unitPrice * item.selectedQuantity);
        },
      );
      
      var finalDiscount = discount;
      if (finalDiscount > subtotal) {
        finalDiscount = subtotal; // Cap discount to subtotal
      }
      
      // جلب إعدادات الضريبة
      final taxEnabledStr = await (_db.select(_db.settings)..where((s) => s.key.equals('tax_enabled'))).getSingleOrNull();
      final taxRateStr = await (_db.select(_db.settings)..where((s) => s.key.equals('tax_rate'))).getSingleOrNull();
      
      final bool isTaxEnabled = taxEnabledStr?.value == 'true';
      final double taxRate = isTaxEnabled ? (double.tryParse(taxRateStr?.value ?? '') ?? 15.0) : 0.0;
      
      final double amountAfterDiscount = subtotal - finalDiscount;
      final double taxAmount = amountAfterDiscount * (taxRate / 100);
      final double totalAmount = amountAfterDiscount + taxAmount;
      
      final invoiceNumber = await _generateInvoiceNumber();

      final saleId = await _db.into(_db.sales).insert(
            SalesCompanion.insert(
              invoiceNumber: invoiceNumber,
              cashierId: Value(cashierId),
              customerId: Value(customerId),
              subTotal: Value(subtotal),
              taxAmount: Value(taxAmount),
              totalAmount: totalAmount,
              discount: Value(finalDiscount),
              paymentMethod: Value(paymentMethod),
              doctorId: Value(doctorId),
              prescriptionId: Value(prescriptionId),
            ),
          );

      for (final item in items) {
        var remaining = item.quantity; // Deduct quantityInBase from batches

        if (item.batchId != null) {
          // 1. Explicit batch specified by user (via SelectBatchDialog)
          final matchingBatches = await (_db.select(_db.batches)
                ..where((b) => b.id.equals(item.batchId!)))
              .get();
              
          if (matchingBatches.isNotEmpty) {
             final targetBatch = matchingBatches.first;
             
             if (targetBatch.quantity < remaining) {
               throw Exception('الكمية المتوفرة في الدفعة المحددة (${targetBatch.quantity}) لا تكفي للصنف ${item.medicineName}');
             }

             await (_db.update(_db.batches)..where((b) => b.id.equals(targetBatch.id)))
                 .write(BatchesCompanion(
               quantity: Value(targetBatch.quantity - remaining),
             ));

             await _db.into(_db.saleItems).insert(
                   SaleItemsCompanion.insert(
                     saleId: saleId,
                     medicineId: item.medicineId,
                     batchId: Value(targetBatch.id),
                     quantity: remaining,
                     unitPrice: item.unitPrice,
                     subtotal: (item.unitPrice / item.conversionFactor) * remaining,
                     taxRate: Value(taxRate),
                     taxAmount: Value(((item.unitPrice / item.conversionFactor) * remaining) * (taxRate / 100)),
                     total: Value(((item.unitPrice / item.conversionFactor) * remaining) * (1 + (taxRate / 100))),
                     unitName: Value(item.unitName),
                     conversionFactor: Value(item.conversionFactor),
                     selectedQuantity: Value(item.selectedQuantity),
                   ),
                 );
                 
             remaining = 0;
          } else {
             throw Exception('الدفعة المحددة غير متوفرة في المخزون للصنف ${item.medicineName}');
          }

        } else {
          // 2. Standard FEFO deduction
          final availableBatches = await (_db.select(_db.batches)
                ..where((b) =>
                    b.medicineId.equals(item.medicineId) &
                    b.quantity.isBiggerThanValue(0)))
              .get();

          // FEFO: الأقرب انتهاءً أولاً - بدون تاريخ انتهاء = الأولوية الأخيرة
          availableBatches.sort((a, b) {
            if (a.expiryDate == null && b.expiryDate == null) return 0;
            if (a.expiryDate == null) return 1;
            if (b.expiryDate == null) return -1;
            return a.expiryDate!.compareTo(b.expiryDate!);
          });

          for (final batch in availableBatches) {
            if (remaining <= 0) break;
            final takeFromBatch = remaining < batch.quantity ? remaining : batch.quantity;

            await (_db.update(_db.batches)..where((b) => b.id.equals(batch.id)))
                .write(BatchesCompanion(
              quantity: Value(batch.quantity - takeFromBatch),
            ));

            await _db.into(_db.saleItems).insert(
                  SaleItemsCompanion.insert(
                    saleId: saleId,
                    medicineId: item.medicineId,
                    batchId: Value(batch.id),
                    quantity: takeFromBatch,
                    unitPrice: item.unitPrice,
                    subtotal: (item.unitPrice / item.conversionFactor) * takeFromBatch,
                    taxRate: Value(taxRate),
                    taxAmount: Value(((item.unitPrice / item.conversionFactor) * takeFromBatch) * (taxRate / 100)),
                    total: Value(((item.unitPrice / item.conversionFactor) * takeFromBatch) * (1 + (taxRate / 100))),
                    unitName: Value(item.unitName),
                    conversionFactor: Value(item.conversionFactor),
                    selectedQuantity: Value(item.selectedQuantity),
                  ),
                );

            remaining -= takeFromBatch;
          }
        }

        if (remaining > 0) {
          throw InsufficientStockException(item.medicineName);
        }
      }

      return (_db.select(_db.sales)..where((s) => s.id.equals(saleId))).getSingle();
    });

    // --- القيود المحاسبية (تُنفذ بأمان بعد تأكيد حفظ الفاتورة والمخزون بنجاح) ---
    try {
      final cashAccId = await _glRepo.getAccountIdByCode('1101');
      final arAccId = await _glRepo.getAccountIdByCode('1103');
      final cogsAccId = await _glRepo.getAccountIdByCode('5101');
      final revAccId = await _glRepo.getAccountIdByCode('4101');
      final inventoryAccId = await _glRepo.getAccountIdByCode('1102');
      
      if (cashAccId != null && arAccId != null && cogsAccId != null && revAccId != null && inventoryAccId != null) {
        final List<JournalEntryLineEntity> lines = [];
        
        final isCredit = paymentMethod == 'آجل';
        final receivableAccId = isCredit ? arAccId : cashAccId;

        // 1. من حـ / الصندوق أو العملاء (مدين) بإجمالي الفاتورة الصافي
        lines.add(JournalEntryLineEntity(
          id: 0, journalEntryId: 0,
          accountId: receivableAccId,
          accountName: '',
          debit: saleResult.totalAmount,
          credit: 0,
          description: 'مبيعات الفاتورة ${saleResult.invoiceNumber}',
        ));
        
        // 2. إلى حـ / إيرادات المبيعات (دائن) بإجمالي الفاتورة الصافي
        lines.add(JournalEntryLineEntity(
          id: 0, journalEntryId: 0,
          accountId: revAccId,
          accountName: '',
          debit: 0,
          credit: saleResult.totalAmount,
          description: 'إيراد الفاتورة ${saleResult.invoiceNumber}',
        ));
        
        // حساب تكلفة البضاعة المباعة
        double totalCost = 0;
        final saleItems = await (_db.select(_db.saleItems)..where((si) => si.saleId.equals(saleResult.id))).get();
        for(var si in saleItems) {
           if (si.batchId != null) {
               final batch = await (_db.select(_db.batches)..where((b) => b.id.equals(si.batchId!))).getSingleOrNull();
               if (batch != null) {
                 totalCost += (batch.purchasePrice ?? 0) * si.quantity;
               }
           }
        }
        
        if (totalCost > 0) {
           // 3. من حـ / تكلفة البضاعة المباعة (مدين)
           lines.add(JournalEntryLineEntity(
             id: 0, journalEntryId: 0,
             accountId: cogsAccId,
             accountName: '',
             debit: totalCost,
             credit: 0,
             description: 'تكلفة مبيعات ${saleResult.invoiceNumber}',
           ));
           
           // 4. إلى حـ / المخزون (دائن)
           lines.add(JournalEntryLineEntity(
             id: 0, journalEntryId: 0,
             accountId: inventoryAccId,
             accountName: '',
             debit: 0,
             credit: totalCost,
             description: 'صرف مخزون للفاتورة ${saleResult.invoiceNumber}',
           ));
        }

        await _glRepo.postJournalEntry(
          referenceNumber: 'JE-${saleResult.invoiceNumber}',
          date: DateTime.now(),
          description: 'تسجيل مبيعات ${saleResult.invoiceNumber}',
          source: 'Sales',
          sourceId: saleResult.id,
          createdBy: cashierId ?? 1,
          lines: lines,
        );
      }
    } catch (e) {
      print('Error posting sale journal entry: $e');
    }

    return saleResult;
  }

  @override
  Future<double> getTodaySalesTotal() async {
    final rows = await (_db.select(_db.sales)
          ..where((s) => s.createdAt.isBiggerOrEqualValue(_startOfToday)))
        .get();
    return rows.fold<double>(0, (sum, s) => sum + s.totalAmount);
  }

  // --- ميزة تعليق الفواتير (Hold Invoices) ---
  @override
  Future<void> suspendSale({
    required List<CartLineInput> items,
    int? cashierId,
    int? customerId,
    String? referenceNote,
  }) async {
    if (items.isEmpty) return;

    // Convert items to simple JSON string
    final cartDataStr = items.map((e) => '${e.medicineId}:${e.medicineName}:${e.quantity}:${e.unitPrice}:${e.unitName}:${e.conversionFactor}:${e.selectedQuantity}').join('|');

    await _db.into(_db.heldInvoices).insert(
      HeldInvoicesCompanion.insert(
        cashierId: Value(cashierId),
        customerId: Value(customerId),
        referenceNote: Value(referenceNote),
        cartData: cartDataStr,
      ),
    );
  }

  @override
  Future<List<HeldInvoiceRow>> getSuspendedSales() async {
    return await (_db.select(_db.heldInvoices)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  @override
  Future<void> deleteSuspendedSale(int id) async {
    await (_db.delete(_db.heldInvoices)..where((t) => t.id.equals(id))).go();
  }
}
