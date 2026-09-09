import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/audit_logger.dart';
import '../../../accounting/domain/repositories/general_ledger_repository.dart';
import '../../../accounting/domain/entities/accounting_entities.dart';
import '../../domain/entities/purchase_returns_entity.dart';
import '../../domain/repositories/purchase_returns_repository.dart';

class PurchaseReturnsRepositoryImpl implements PurchaseReturnsRepository {
  final AppDatabase _db;
  final AuditLogger _auditLogger;
  final GeneralLedgerRepository _glRepo;

  PurchaseReturnsRepositoryImpl(this._db, this._auditLogger, this._glRepo);

  @override
  Future<PurchaseReturnEntity> createPurchaseReturn({
    required int supplierId,
    required String paymentMethod,
    required List<PurchaseReturnItemInput> items,
    int? recordedBy,
    String? notes,
  }) async {
    return _db.transaction(() async {
      double totalAmount = 0;
      for (final item in items) {
        totalAmount += (item.quantity * item.unitPrice);
      }

      final now = DateTime.now();
      final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      
      final todayCount = await (_db.select(_db.purchaseReturns)
            ..where((r) => r.createdAt.isBiggerOrEqualValue(DateTime(now.year, now.month, now.day))))
          .get()
          .then((rows) => rows.length);
          
      final seq = (todayCount + 1).toString().padLeft(4, '0');
      final refNumber = 'PR-$datePart-$seq';

      final returnId = await _db.into(_db.purchaseReturns).insert(
            PurchaseReturnsCompanion.insert(
              referenceNumber: refNumber,
              supplierId: supplierId,
              totalAmount: totalAmount,
              paymentMethod: Value(paymentMethod),
              recordedBy: recordedBy ?? 1,
              notes: Value(notes),
            ),
          );

      for (final item in items) {
        // سحب الكمية من الدفعة المحددة
        final batch = await (_db.select(_db.batches)..where((b) => b.id.equals(item.batchId))).getSingle();
        if (batch.quantity < item.quantity) {
          throw Exception('الكمية المراد إرجاعها أكبر من المتوفر في الدفعة');
        }

        await (_db.update(_db.batches)..where((b) => b.id.equals(item.batchId))).write(
          BatchesCompanion(
            quantity: Value(batch.quantity - item.quantity),
          ),
        );

        await _db.into(_db.purchaseReturnItems).insert(
              PurchaseReturnItemsCompanion.insert(
                returnId: returnId,
                medicineId: item.medicineId,
                batchId: item.batchId,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                subtotal: (item.quantity * item.unitPrice),
                reason: Value(item.reason),
              ),
            );
      }

      await _auditLogger.log(
        actionType: 'PURCHASE_RETURN_CREATED',
        tableName: 'purchase_returns',
        recordId: returnId.toString(),
        userId: recordedBy,
        newValue: 'ref=$refNumber, total=$totalAmount',
      );

      // --- القيد المحاسبي المزدوج ---
      try {
        final apAccId = await _glRepo.getAccountIdByCode('2101'); // الموردين
        final inventoryAccId = await _glRepo.getAccountIdByCode('1102'); // المخزون
        final cashAccId = await _glRepo.getAccountIdByCode('1101'); // الصندوق

        if (apAccId != null && inventoryAccId != null && cashAccId != null) {
          final isCash = paymentMethod == 'نقدي';
          final List<JournalEntryLineEntity> lines = [];

          // المورد مدين (أو الصندوق مدين إذا استلمنا كاش)
          lines.add(JournalEntryLineEntity(
            id: 0, journalEntryId: 0,
            accountId: isCash ? cashAccId : apAccId,
            accountName: '',
            debit: totalAmount,
            credit: 0,
            description: 'مردودات مشتريات للفاتورة $refNumber',
          ));

          // المخزون دائن (نقص المخزون)
          lines.add(JournalEntryLineEntity(
            id: 0, journalEntryId: 0,
            accountId: inventoryAccId,
            accountName: '',
            debit: 0,
            credit: totalAmount,
            description: 'سحب مخزون لمردودات المشتريات $refNumber',
          ));

          await _glRepo.postJournalEntry(
            referenceNumber: 'JE-$refNumber',
            date: DateTime.now(),
            description: 'مردودات مشتريات $refNumber',
            source: 'PurchaseReturns',
            sourceId: returnId,
            createdBy: recordedBy,
            lines: lines,
          );
        }
      } catch (e) {
        print('فشل تسجيل القيد المحاسبي لمردودات المشتريات: $e');
      }

      return (await getAllPurchaseReturns()).firstWhere((r) => r.id == returnId);
    });
  }

  @override
  Future<List<PurchaseReturnEntity>> getAllPurchaseReturns() async {
    final rows = await _db.select(_db.purchaseReturns).get();
    final List<PurchaseReturnEntity> entities = [];

    for (final row in rows) {
      final supplier = await (_db.select(_db.suppliers)..where((s) => s.id.equals(row.supplierId))).getSingle();
      
      final itemRows = await (_db.select(_db.purchaseReturnItems)..where((i) => i.returnId.equals(row.id))).get();
      final List<PurchaseReturnItemEntity> items = [];
      
      for (final item in itemRows) {
        final medicine = await (_db.select(_db.medicines)..where((m) => m.id.equals(item.medicineId))).getSingle();
        items.add(PurchaseReturnItemEntity(
          medicineId: item.medicineId,
          medicineName: medicine.nameAr,
          batchId: item.batchId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          subtotal: item.subtotal,
          reason: item.reason,
        ));
      }

      entities.add(PurchaseReturnEntity(
        id: row.id,
        referenceNumber: row.referenceNumber,
        supplierId: row.supplierId,
        supplierName: supplier.name,
        totalAmount: row.totalAmount,
        paymentMethod: row.paymentMethod,
        createdAt: row.createdAt,
        notes: row.notes,
        items: items,
      ));
    }

    return entities;
  }
}
