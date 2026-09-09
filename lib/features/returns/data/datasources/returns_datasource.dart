// منطق المرتجعات - كل عملية إرجاع تتحقق أولًا من عدم تجاوز الكمية المسموحة
// (originalQuantity - alreadyReturned)، ثم تُنفَّذ ذرّيًا (transaction).
//
// مرتجع عميل: يعيد الكمية لنفس الدفعة (Batch) التي بيعت منها بالضبط،
// ويحدّث حالة الفاتورة (completed/partially_returned/returned).
// مرتجع مورد: يخصم الكمية من نفس الدفعة التي استُلمت فيها (لا يمكن إرجاع
// أكثر مما هو موجود فعليًا في تلك الدفعة حاليًا، لأن جزءًا منها قد يكون بيع بالفعل).

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/returns_entity.dart';
import '../../../accounting/domain/repositories/general_ledger_repository.dart';
import '../../../accounting/domain/entities/accounting_entities.dart';

abstract class ReturnsDataSource {
  Future<SaleLookupResult?> findSaleByInvoiceNumber(String invoiceNumber);
  Future<List<SaleLookupResult>> findSalesByMedicineName(String medicineName);
  Future<List<SaleLookupResult>> getRecentSalesForReturns({int limit = 50});
  Future<PurchaseLookupResult?> findPurchaseByNumber(String purchaseNumber);

  Future<void> createCustomerReturnTransactional({
    required int saleItemId,
    required int quantity,
    required int qtyCarton,
    required int qtyPack,
    required int qtyStrip,
    required int qtyPill,
    String? reason,
    int? processedBy,
  });
  
  Future<void> processBulkCustomerReturn({
    required int saleId,
    required Map<int, int> returnQuantities, // saleItemId -> quantity
    String? reason,
    int? processedBy,
  });

  Future<void> createVendorReturnTransactional({
    required int purchaseItemId,
    required int quantity,
    required int qtyCarton,
    required int qtyPack,
    required int qtyStrip,
    required int qtyPill,
    String? reason,
    int? processedBy,
  });

  Future<double> getTodayReturnsTotal();
}

class ReturnsDataSourceImpl implements ReturnsDataSource {
  final AppDatabase _db;
  final GeneralLedgerRepository _glRepo;
  ReturnsDataSourceImpl(this._db, this._glRepo);

  Future<Map<int, String>> _medicineNameMap() async {
    final rows = await _db.select(_db.medicines).get();
    return {for (final m in rows) m.id: m.nameAr};
  }

  Future<int> _returnedQuantityForSaleItem(int saleItemId) async {
    final rows = await (_db.select(_db.returnItems)
          ..where((r) => r.originalSaleItemId.equals(saleItemId)))
        .get();
    return rows.fold<int>(0, (sum, r) => sum + r.quantity);
  }

  Future<int> _returnedQuantityForPurchaseItem(int purchaseItemId) async {
    final rows = await (_db.select(_db.returnItems)
          ..where((r) => r.originalPurchaseItemId.equals(purchaseItemId)))
        .get();
    return rows.fold<int>(0, (sum, r) => sum + r.quantity);
  }

  @override
  Future<SaleLookupResult?> findSaleByInvoiceNumber(String invoiceNumber) async {
    final sale = await (_db.select(_db.sales)
          ..where((s) => s.invoiceNumber.equals(invoiceNumber.trim())))
        .getSingleOrNull();
    if (sale == null) return null;

    final items = await (_db.select(_db.saleItems)..where((si) => si.saleId.equals(sale.id))).get();
    final medicineNames = await _medicineNameMap();

    final lookups = <SaleItemLookup>[];
    for (final item in items) {
      final returned = await _returnedQuantityForSaleItem(item.id);
      lookups.add(SaleItemLookup(
        saleItemId: item.id,
        medicineId: item.medicineId,
        medicineName: medicineNames[item.medicineId] ?? 'غير معروف',
        originalQuantity: item.quantity,
        alreadyReturned: returned,
        unitPrice: item.unitPrice,
      ));
    }

    return SaleLookupResult(saleId: sale.id, invoiceNumber: sale.invoiceNumber, items: lookups);
  }
  
  @override
  Future<List<SaleLookupResult>> findSalesByMedicineName(String medicineName) async {
    final meds = await (_db.select(_db.medicines)..where((m) => m.nameAr.contains(medicineName) | m.nameEn.contains(medicineName))).get();
    if (meds.isEmpty) return [];
    final medIds = meds.map((m) => m.id).toList();

    final saleItems = await (_db.select(_db.saleItems)..where((si) => si.medicineId.isIn(medIds))).get();
    if (saleItems.isEmpty) return [];
    
    final saleIds = saleItems.map((si) => si.saleId).toSet().toList();
    final sales = await (_db.select(_db.sales)..where((s) => s.id.isIn(saleIds))
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])).get();

    final List<SaleLookupResult> results = [];
    for (final sale in sales) {
      final res = await findSaleByInvoiceNumber(sale.invoiceNumber);
      if (res != null) results.add(res);
    }
    return results;
  }

  @override
  Future<List<SaleLookupResult>> getRecentSalesForReturns({int limit = 50}) async {
    final sales = await (_db.select(_db.sales)
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
          ..limit(limit))
        .get();
        
    final List<SaleLookupResult> results = [];
    for (final sale in sales) {
      final res = await findSaleByInvoiceNumber(sale.invoiceNumber);
      if (res != null) results.add(res);
    }
    return results;
  }

  @override
  Future<PurchaseLookupResult?> findPurchaseByNumber(String purchaseNumber) async {
    final purchase = await (_db.select(_db.purchases)
          ..where((p) => p.purchaseNumber.equals(purchaseNumber.trim())))
        .getSingleOrNull();
    if (purchase == null) return null;

    final items =
        await (_db.select(_db.purchaseItems)..where((pi) => pi.purchaseId.equals(purchase.id))).get();
    final medicineNames = await _medicineNameMap();

    final lookups = <PurchaseItemLookup>[];
    for (final item in items) {
      final returned = await _returnedQuantityForPurchaseItem(item.id);
      final batch =
          await (_db.select(_db.batches)..where((b) => b.id.equals(item.batchId))).getSingle();
      lookups.add(PurchaseItemLookup(
        purchaseItemId: item.id,
        batchId: item.batchId,
        medicineId: item.medicineId,
        medicineName: medicineNames[item.medicineId] ?? 'غير معروف',
        originalQuantity: item.quantity,
        alreadyReturned: returned,
        currentBatchQuantity: batch.quantity,
        unitCost: item.unitCost,
      ));
    }

    return PurchaseLookupResult(
        purchaseId: purchase.id, purchaseNumber: purchase.purchaseNumber, items: lookups);
  }

  Future<void> _recomputeSaleStatus(int saleId) async {
    final items = await (_db.select(_db.saleItems)..where((si) => si.saleId.equals(saleId))).get();
    var totalOriginal = 0;
    var totalReturned = 0;
    for (final item in items) {
      totalOriginal += item.quantity;
      totalReturned += await _returnedQuantityForSaleItem(item.id);
    }
    final newStatus = totalReturned == 0
        ? 'completed'
        : (totalReturned >= totalOriginal ? 'returned' : 'partially_returned');

    await (_db.update(_db.sales)..where((s) => s.id.equals(saleId)))
        .write(SalesCompanion(status: Value(newStatus)));
  }

  @override
  Future<void> createCustomerReturnTransactional({
    required int saleItemId,
    required int quantity,
    required int qtyCarton,
    required int qtyPack,
    required int qtyStrip,
    required int qtyPill,
    String? reason,
    int? processedBy,
  }) async {
    await _db.transaction(() async {
      final saleItem =
          await (_db.select(_db.saleItems)..where((si) => si.id.equals(saleItemId))).getSingle();
      final alreadyReturned = await _returnedQuantityForSaleItem(saleItemId);
      final maxReturnable = saleItem.quantity - alreadyReturned;

      if (quantity <= 0 || quantity > maxReturnable) {
        final medicine = await (_db.select(_db.medicines)
              ..where((m) => m.id.equals(saleItem.medicineId)))
            .getSingle();
        throw ReturnQuantityExceededException(medicine.nameAr);
      }

      final amountRefunded = (saleItem.unitPrice / (saleItem.conversionFactor ?? 1)) * quantity;

      final returnId = await _db.into(_db.returns).insert(
            ReturnsCompanion.insert(
              saleId: Value(saleItem.saleId),
              totalAmount: Value(amountRefunded),
              reason: Value(reason),
              processedBy: Value(processedBy),
            ),
          );

      await _db.into(_db.returnItems).insert(
            ReturnItemsCompanion.insert(
              returnId: returnId,
              medicineId: saleItem.medicineId,
              quantity: quantity,
              qtyCarton: Value(qtyCarton),
              qtyPack: Value(qtyPack),
              qtyStrip: Value(qtyStrip),
              qtyPill: Value(qtyPill),
              unitPrice: saleItem.unitPrice,
              subtotal: amountRefunded,
              originalSaleItemId: Value(saleItemId),
            ),
          );

      double batchCost = 0;
      if (saleItem.batchId != null) {
        final batch =
            await (_db.select(_db.batches)..where((b) => b.id.equals(saleItem.batchId!))).getSingle();
        await (_db.update(_db.batches)..where((b) => b.id.equals(batch.id)))
            .write(BatchesCompanion(quantity: Value(batch.quantity + quantity)));
        batchCost = (batch.purchasePrice ?? 0) * quantity;
      }

      await _recomputeSaleStatus(saleItem.saleId);
      
      // المحاسبة: مرتجع مبيعات
      try {
        final sale = await (_db.select(_db.sales)..where((s) => s.id.equals(saleItem.saleId))).getSingle();
        
        final cashAccId = await _glRepo.getAccountIdByCode('1101');
        final arAccId = await _glRepo.getAccountIdByCode('1103');
        final invAccId = await _glRepo.getAccountIdByCode('1102');
        final revAccId = await _glRepo.getAccountIdByCode('4101'); // Revenue (contra)
        final cogsAccId = await _glRepo.getAccountIdByCode('5101');
        
        if (cashAccId != null && revAccId != null && invAccId != null && cogsAccId != null && arAccId != null) {
          final isCredit = sale.paymentMethod == 'آجل';
          final receivableAccId = isCredit ? arAccId : cashAccId;
          
          await _glRepo.postJournalEntry(
            referenceNumber: 'SR-$returnId',
            date: DateTime.now(),
            description: 'مرتجع مبيعات للفاتورة ${sale.invoiceNumber}',
            source: 'SalesReturn',
            sourceId: returnId,
            createdBy: processedBy ?? 1,
            lines: [
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0, accountId: revAccId, accountName: '',
                debit: amountRefunded, credit: 0, description: 'تخفيض إيرادات',
              ),
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0, accountId: receivableAccId, accountName: '',
                debit: 0, credit: amountRefunded, description: 'استرداد قيمة للعميل',
              ),
              if (batchCost > 0) ...[
                JournalEntryLineEntity(
                  id: 0, journalEntryId: 0, accountId: invAccId, accountName: '',
                  debit: batchCost, credit: 0, description: 'استرجاع مخزون',
                ),
                JournalEntryLineEntity(
                  id: 0, journalEntryId: 0, accountId: cogsAccId, accountName: '',
                  debit: 0, credit: batchCost, description: 'عكس تكلفة البضاعة المباعة',
                ),
              ],
            ],
          );
        }
      } catch(e) {
        // ignore
      }
    });
  }

  @override
  Future<void> processBulkCustomerReturn({
    required int saleId,
    required Map<int, int> returnQuantities,
    String? reason,
    int? processedBy,
  }) async {
    return _db.transaction(() async {
      final sale = await (_db.select(_db.sales)..where((s) => s.id.equals(saleId))).getSingle();
      
      final returnId = await _db.into(_db.returns).insert(
        ReturnsCompanion.insert(
          saleId: Value(saleId),
          reason: Value(reason),
          processedBy: Value(processedBy),
        ),
      );

      double totalAmountRefunded = 0;
      double totalBatchCost = 0;

      for (final entry in returnQuantities.entries) {
        final saleItemId = entry.key;
        final quantity = entry.value;
        if (quantity <= 0) continue;

        final saleItem = await (_db.select(_db.saleItems)..where((si) => si.id.equals(saleItemId))).getSingle();
        final alreadyReturned = await _returnedQuantityForSaleItem(saleItemId);
        final maxReturnable = saleItem.quantity - alreadyReturned;

        if (quantity > maxReturnable) {
          final medicine = await (_db.select(_db.medicines)..where((m) => m.id.equals(saleItem.medicineId))).getSingle();
          throw ReturnQuantityExceededException(medicine.nameAr);
        }

        final amountRefunded = (saleItem.unitPrice / (saleItem.conversionFactor ?? 1)) * quantity;
        totalAmountRefunded += amountRefunded;

        await _db.into(_db.returnItems).insert(
          ReturnItemsCompanion.insert(
            returnId: returnId,
            medicineId: saleItem.medicineId,
            quantity: quantity,
            unitPrice: saleItem.unitPrice,
            subtotal: amountRefunded,
            originalSaleItemId: Value(saleItemId),
          ),
        );

        if (saleItem.batchId != null) {
          final batch = await (_db.select(_db.batches)..where((b) => b.id.equals(saleItem.batchId!))).getSingle();
          await (_db.update(_db.batches)..where((b) => b.id.equals(batch.id)))
              .write(BatchesCompanion(quantity: Value(batch.quantity + quantity)));
          totalBatchCost += (batch.purchasePrice ?? 0) * quantity;
        }
      }

      // Update totalAmount in returns table
      await (_db.update(_db.returns)..where((r) => r.id.equals(returnId)))
          .write(ReturnsCompanion(totalAmount: Value(totalAmountRefunded)));

      await _recomputeSaleStatus(saleId);

      // المحاسبة: مرتجع مبيعات مجمع
      try {
        final cashAccId = await _glRepo.getAccountIdByCode('1101');
        final arAccId = await _glRepo.getAccountIdByCode('1103');
        final invAccId = await _glRepo.getAccountIdByCode('1102');
        final revAccId = await _glRepo.getAccountIdByCode('4101');
        final cogsAccId = await _glRepo.getAccountIdByCode('5101');
        
        if (cashAccId != null && revAccId != null && invAccId != null && cogsAccId != null && arAccId != null && totalAmountRefunded > 0) {
          final isCredit = sale.paymentMethod == 'آجل';
          final receivableAccId = isCredit ? arAccId : cashAccId;
          
          await _glRepo.postJournalEntry(
            referenceNumber: 'SR-$returnId',
            date: DateTime.now(),
            description: 'مرتجع مبيعات شامل للفاتورة ${sale.invoiceNumber}',
            source: 'SalesReturn',
            sourceId: returnId,
            createdBy: processedBy ?? 1,
            lines: [
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0, accountId: revAccId, accountName: '',
                debit: totalAmountRefunded, credit: 0, description: 'تخفيض إيرادات',
              ),
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0, accountId: receivableAccId, accountName: '',
                debit: 0, credit: totalAmountRefunded, description: 'استرداد قيمة للعميل',
              ),
              if (totalBatchCost > 0) ...[
                JournalEntryLineEntity(
                  id: 0, journalEntryId: 0, accountId: invAccId, accountName: '',
                  debit: totalBatchCost, credit: 0, description: 'استرجاع مخزون',
                ),
                JournalEntryLineEntity(
                  id: 0, journalEntryId: 0, accountId: cogsAccId, accountName: '',
                  debit: 0, credit: totalBatchCost, description: 'عكس تكلفة البضاعة المباعة',
                ),
              ],
            ],
          );
        }
      } catch(e) {
        // ignore
      }
    });
  }

  @override
  Future<void> createVendorReturnTransactional({
    required int purchaseItemId,
    required int quantity,
    required int qtyCarton,
    required int qtyPack,
    required int qtyStrip,
    required int qtyPill,
    String? reason,
    int? processedBy,
  }) async {
    await _db.transaction(() async {
      final purchaseItem = await (_db.select(_db.purchaseItems)
            ..where((pi) => pi.id.equals(purchaseItemId)))
          .getSingle();
      final alreadyReturned = await _returnedQuantityForPurchaseItem(purchaseItemId);
      final batch = await (_db.select(_db.batches)..where((b) => b.id.equals(purchaseItem.batchId)))
          .getSingle();

      final maxByOriginal = purchaseItem.quantity - alreadyReturned;
      final maxReturnable = maxByOriginal < batch.quantity ? maxByOriginal : batch.quantity;

      if (quantity <= 0 || quantity > maxReturnable) {
        final medicine = await (_db.select(_db.medicines)
              ..where((m) => m.id.equals(purchaseItem.medicineId)))
            .getSingle();
        throw ReturnQuantityExceededException(medicine.nameAr);
      }

      final returnedCost = purchaseItem.unitCost * quantity;

      final returnId = await _db.into(_db.returns).insert(
            ReturnsCompanion.insert(
              purchaseId: Value(purchaseItem.purchaseId),
              totalAmount: Value(returnedCost),
              reason: Value(reason),
              processedBy: Value(processedBy),
            ),
          );

      await _db.into(_db.returnItems).insert(
            ReturnItemsCompanion.insert(
              returnId: returnId,
              medicineId: purchaseItem.medicineId,
              quantity: quantity,
              qtyCarton: Value(qtyCarton),
              qtyPack: Value(qtyPack),
              qtyStrip: Value(qtyStrip),
              qtyPill: Value(qtyPill),
              unitPrice: purchaseItem.unitCost,
              subtotal: returnedCost,
              originalPurchaseItemId: Value(purchaseItemId),
            ),
          );

      await (_db.update(_db.batches)..where((b) => b.id.equals(batch.id)))
          .write(BatchesCompanion(quantity: Value(batch.quantity - quantity)));
          
      // المحاسبة: مرتجع مشتريات
      try {
        final purchase = await (_db.select(_db.purchases)..where((p) => p.id.equals(purchaseItem.purchaseId))).getSingle();
        
        final cashAccId = await _glRepo.getAccountIdByCode('1101');
        final apAccId = await _glRepo.getAccountIdByCode('2101');
        final invAccId = await _glRepo.getAccountIdByCode('1102');
        
        if (cashAccId != null && apAccId != null && invAccId != null) {
          final isCredit = purchase.paymentMethod == 'آجل';
          final payableAccId = isCredit ? apAccId : cashAccId;
          
          await _glRepo.postJournalEntry(
            referenceNumber: 'PR-$returnId',
            date: DateTime.now(),
            description: 'مرتجع مشتريات للمورد',
            source: 'PurchaseReturn',
            sourceId: returnId,
            createdBy: processedBy ?? 1,
            lines: [
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0, accountId: payableAccId, accountName: '',
                debit: returnedCost, credit: 0, description: 'استرداد قيمة من المورد',
              ),
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0, accountId: invAccId, accountName: '',
                debit: 0, credit: returnedCost, description: 'تخفيض مخزون',
              ),
            ],
          );
        }
      } catch (e) {
        // ignore
      }
    });
  }

  @override
  Future<double> getTodayReturnsTotal() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final rows = await (_db.select(_db.returns)
          ..where((r) => r.createdAt.isBiggerOrEqualValue(startOfToday) & r.saleId.isNotNull()))
        .get();
    return rows.fold<double>(0, (sum, r) => sum + r.totalAmount);
  }
}
