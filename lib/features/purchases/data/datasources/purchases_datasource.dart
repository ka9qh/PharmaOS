// إنشاء فاتورة شراء بشكل ذرّي: فاتورة + دفعة (Batch) جديدة لكل سطر + بند شراء لكل دفعة.
// عكس البيع تمامًا: هنا "نُضيف" مخزونًا جديدًا، فلا حاجة لمنطق FEFO أو بحث عن دفعات قائمة.

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../accounting/domain/repositories/general_ledger_repository.dart';
import '../../../accounting/domain/entities/accounting_entities.dart';

abstract class PurchasesDataSource {
  Future<PurchaseRow> createPurchaseTransactional({
    required int supplierId,
    String? supplierInvoiceRef,
    required List<({int medicineId, int quantity, double unitCost, double? sellingPrice, String? batchNumber, DateTime? expiryDate, int qtyCarton, int qtyPack, int qtyStrip, int qtyPill})> items,
    required double paidAmount,
    String? invoiceImagePath,
  });

  Future<List<PurchaseRow>> listRecent({int limit = 50});
}

class PurchasesDataSourceImpl implements PurchasesDataSource {
  final AppDatabase _db;
  final GeneralLedgerRepository _glRepo;
  PurchasesDataSourceImpl(this._db, this._glRepo);

  Future<String> _generatePurchaseNumber() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final todayCount = await (_db.select(_db.purchases)
          ..where((p) => p.createdAt.isBiggerOrEqualValue(startOfDay)))
        .get()
        .then((rows) => rows.length);
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final seq = (todayCount + 1).toString().padLeft(4, '0');
    return 'PUR-$datePart-$seq';
  }

  Future<PurchaseRow> createPurchaseTransactional({
    required int supplierId,
    String? supplierInvoiceRef,
    required List<({int medicineId, int quantity, double unitCost, double? sellingPrice, String? batchNumber, DateTime? expiryDate, int qtyCarton, int qtyPack, int qtyStrip, int qtyPill})> items,
    required double paidAmount,
    String? invoiceImagePath,
  }) async {
    if (items.isEmpty) {
      throw const FormatException('لا يمكن إنشاء فاتورة شراء فارغة بدون أصناف.');
    }

    if (paidAmount < 0) {
      throw const FormatException('المبلغ المدفوع لا يمكن أن يكون سالباً.');
    }

    final purchaseResult = await _db.transaction(() async {
      final totalAmount = items.fold<double>(
        0,
        (sum, item) {
          if (item.quantity <= 0) {
            throw const FormatException('الكمية يجب أن تكون أكبر من صفر.');
          }
          if (item.unitCost < 0) {
            throw const FormatException('سعر الشراء لا يمكن أن يكون سالباً.');
          }
          return sum + (item.unitCost * item.quantity);
        },
      );
      
      var finalPaidAmount = paidAmount;
      if (finalPaidAmount > totalAmount) {
        finalPaidAmount = totalAmount; // Cap paid amount to total amount
      }

      // جلب إعدادات الضريبة
      final taxEnabledStr = await (_db.select(_db.settings)..where((s) => s.key.equals('tax_enabled'))).getSingleOrNull();
      final taxRateStr = await (_db.select(_db.settings)..where((s) => s.key.equals('tax_rate'))).getSingleOrNull();
      
      final bool isTaxEnabled = taxEnabledStr?.value == 'true';
      final double taxRate = isTaxEnabled ? (double.tryParse(taxRateStr?.value ?? '') ?? 15.0) : 0.0;
      
      final double taxAmount = totalAmount * (taxRate / 100);
      final double finalTotalAmount = totalAmount + taxAmount;

      final purchaseNumber = await _generatePurchaseNumber();

      final purchaseId = await _db.into(_db.purchases).insert(
            PurchasesCompanion.insert(
              purchaseNumber: purchaseNumber,
              supplierInvoiceRef: Value(supplierInvoiceRef),
              supplierId: supplierId,
              subTotal: Value(totalAmount),
              taxAmount: Value(taxAmount),
              totalAmount: finalTotalAmount,
              paidAmount: Value(finalPaidAmount),
              invoiceImagePath: Value(invoiceImagePath),
            ),
          );

      for (final item in items) {
        final batchId = await _db.into(_db.batches).insert(
              BatchesCompanion.insert(
                medicineId: item.medicineId,
                batchNumber: Value(item.batchNumber),
                expiryDate: Value(item.expiryDate),
                quantity: item.quantity,
                purchasePrice: item.unitCost,
              ),
            );

        await _db.into(_db.purchaseItems).insert(
              PurchaseItemsCompanion.insert(
                purchaseId: purchaseId,
                medicineId: item.medicineId,
                batchId: batchId,
                quantity: item.quantity,
                qtyCarton: Value(item.qtyCarton),
                qtyPack: Value(item.qtyPack),
                qtyStrip: Value(item.qtyStrip),
                qtyPill: Value(item.qtyPill),
                unitCost: item.unitCost,
                subtotal: item.unitCost * item.quantity,
                taxRate: Value(taxRate),
                taxAmount: Value((item.unitCost * item.quantity) * (taxRate / 100)),
                total: Value((item.unitCost * item.quantity) * (1 + (taxRate / 100))),
              ),
            );
            
        // تحديث سعر الدواء في الكتالوج إذا تم تغييره
        if (item.sellingPrice != null) {
          await (_db.update(_db.medicines)..where((m) => m.id.equals(item.medicineId))).write(
            MedicinesCompanion(
              purchasePrice: Value(item.unitCost),
              sellingPrice: Value(item.sellingPrice!),
            ),
          );
        }
      }

      return (_db.select(_db.purchases)..where((p) => p.id.equals(purchaseId))).getSingle();
    });

    // --- القيود المحاسبية (تُنفذ بعد حفظ الفاتورة بنجاح) ---
    try {
      final inventoryAccId = await _glRepo.getAccountIdByCode('1102');
      final apAccId = await _glRepo.getAccountIdByCode('2101-$supplierId') ?? await _glRepo.getAccountIdByCode('2101');
      final cashAccId = await _glRepo.getAccountIdByCode('1101');
      
      if (inventoryAccId != null && apAccId != null && cashAccId != null) {
        final List<JournalEntryLineEntity> lines = [];
        
        // المخزون مدين بإجمالي الفاتورة
        lines.add(JournalEntryLineEntity(
          id: 0, journalEntryId: 0,
          accountId: inventoryAccId,
          accountName: '',
          debit: purchaseResult.totalAmount,
          credit: 0,
          description: 'مشتريات الفاتورة ${purchaseResult.purchaseNumber}',
        ));
        
        if (purchaseResult.paidAmount > 0) {
          // دفعنا جزء كاش أو كل المبلغ كاش -> الصندوق دائن
          lines.add(JournalEntryLineEntity(
            id: 0, journalEntryId: 0,
            accountId: cashAccId,
            accountName: '',
            debit: 0,
            credit: purchaseResult.paidAmount,
            description: 'دفعة مشتريات ${purchaseResult.purchaseNumber}',
          ));
        }
        
        final remainingDebt = purchaseResult.totalAmount - purchaseResult.paidAmount;
        if (remainingDebt > 0) {
          // المورد دائن بالباقي
          lines.add(JournalEntryLineEntity(
            id: 0, journalEntryId: 0,
            accountId: apAccId,
            accountName: '',
            debit: 0,
            credit: remainingDebt,
            description: 'آجل مشتريات ${purchaseResult.purchaseNumber}',
          ));
        }

        await _glRepo.postJournalEntry(
          referenceNumber: 'JE-${purchaseResult.purchaseNumber}',
          date: DateTime.now(),
          description: 'تسجيل مشتريات ${purchaseResult.purchaseNumber}',
          source: 'Purchases',
          sourceId: purchaseResult.id,
          createdBy: 1,
          lines: lines,
        );
      }
    } catch (e) {
      print('Error posting purchase journal entry: $e');
    }

    return purchaseResult;
  }

  @override
  Future<List<PurchaseRow>> listRecent({int limit = 50}) {
    return (_db.select(_db.purchases)
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)])
          ..limit(limit))
        .get();
  }
}
