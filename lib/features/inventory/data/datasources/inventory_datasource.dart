import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../accounting/domain/repositories/general_ledger_repository.dart';
import '../../../accounting/domain/entities/accounting_entities.dart';

class StockRowData {
  final int medicineId;
  final String medicineName;
  final int reorderLevel;
  final int totalQuantity;
  final String barcode;
  final double sellingPrice;
  final double purchasePrice;
  final int? batchId;
  final String? batchNumber;
  final DateTime? expiryDate;
  final int? qtyPerPack;
  final int? qtyPerStrip;
  final int? qtyPerCarton;

  const StockRowData({
    required this.medicineId,
    required this.medicineName,
    required this.reorderLevel,
    required this.totalQuantity,
    this.barcode = '',
    this.sellingPrice = 0.0,
    this.purchasePrice = 0.0,
    this.batchId,
    this.batchNumber,
    this.expiryDate,
    this.qtyPerPack,
    this.qtyPerStrip,
    this.qtyPerCarton,
  });
}

abstract class InventoryDataSource {
  Future<List<StockRowData>> getStockOverview();
  Future<int> getAvailableQuantity(int medicineId);
  Future<List<BatchRow>> getBatchesForMedicine(int medicineId);

  Future<void> receiveStock({
    required int medicineId,
    String? batchNumber,
    DateTime? expiryDate,
    required int quantity,
    required double purchasePrice,
  });

  Future<void> writeOffStock({
    required int medicineId,
    required int quantity,
    required String reason,
    String? notes,
    int? recordedBy,
  });

  Future<void> reconcileStock({
    required int medicineId,
    required double actualQuantity,
    required double systemQuantity,
    String? note,
    int? userId,
  });

  Future<void> deleteStockRecords(int medicineId);
  Future<void> deleteSingleBatch(int batchId);
}

class InventoryDataSourceImpl implements InventoryDataSource {
  final AppDatabase _db;
  final GeneralLedgerRepository _glRepo;
  InventoryDataSourceImpl(this._db, this._glRepo);

  @override
  Future<List<StockRowData>> getStockOverview() async {
    // استعلام SQL مباشر (Custom Query)
    // نجلب الدفعات منفصلة في المخزون
    final rows = await _db.customSelect(
      'SELECT m.id AS medicine_id, m.name_ar AS name_ar, '
      'm.reorder_level AS reorder_level, '
      'm.barcode AS barcode, m.selling_price AS selling_price, m.purchase_price AS purchase_price, '
      'm.qty_per_pack AS qty_per_pack, m.qty_per_strip AS qty_per_strip, m.qty_per_carton AS qty_per_carton, '
      'b.id AS batch_id, b.batch_number AS batch_number, b.expiry_date AS expiry_date, '
      'b.quantity AS total_quantity '
      'FROM medicines m INNER JOIN batches b ON b.medicine_id = m.id '
      'WHERE m.is_active = 1 AND b.quantity > 0 '
      'ORDER BY m.name_ar ASC, b.expiry_date ASC',
      readsFrom: {_db.medicines, _db.batches},
    ).get();

    return rows
        .map((row) => StockRowData(
              medicineId: row.read<int>('medicine_id'),
              medicineName: row.read<String>('name_ar'),
              reorderLevel: row.read<int>('reorder_level'),
              totalQuantity: row.read<int>('total_quantity'),
              barcode: row.read<String>('barcode'),
              sellingPrice: row.read<double>('selling_price'),
              purchasePrice: row.read<double>('purchase_price'),
              batchId: row.read<int?>('batch_id'),
              batchNumber: row.read<String?>('batch_number'),
              expiryDate: row.read<DateTime?>('expiry_date'),
              qtyPerPack: row.read<int?>('qty_per_pack'),
              qtyPerStrip: row.read<int?>('qty_per_strip'),
              qtyPerCarton: row.read<int?>('qty_per_carton'),
            ))
        .toList();
  }

  @override
  Future<int> getAvailableQuantity(int medicineId) async {
    final query = _db.select(_db.batches)
      ..where((t) => t.medicineId.equals(medicineId));
    final batches = await query.get();
    return batches.fold<int>(0, (sum, batch) => sum + batch.quantity);
  }

  @override
  Future<List<BatchRow>> getBatchesForMedicine(int medicineId) async {
    final query = _db.select(_db.batches)
      ..where((t) => t.medicineId.equals(medicineId) & t.quantity.isBiggerThanValue(0))
      ..orderBy([(t) => OrderingTerm(expression: t.expiryDate, mode: OrderingMode.asc)]);
    return query.get();
  }

  @override
  Future<void> receiveStock({
    required int medicineId,
    String? batchNumber,
    DateTime? expiryDate,
    required int quantity,
    required double purchasePrice,
  }) async {
    await _db.transaction(() async {
      // 1. إضافة الدفعة في المخزون
      final batchId = await _db.into(_db.batches).insert(
            BatchesCompanion.insert(
              medicineId: medicineId,
              batchNumber: Value(batchNumber),
              expiryDate: Value(expiryDate),
              quantity: quantity,
              purchasePrice: purchasePrice,
            ),
          );

      // 2. جلب بيانات الدواء والمورد لربط الفاتورة
      final med = await (_db.select(_db.medicines)..where((m) => m.id.equals(medicineId))).getSingleOrNull();
      int effectiveSupplierId = med?.supplierId ?? 1;

      final supplierExists = await (_db.select(_db.suppliers)..where((s) => s.id.equals(effectiveSupplierId))).getSingleOrNull();
      if (supplierExists == null) {
        final anySupplier = await (_db.select(_db.suppliers)..limit(1)).getSingleOrNull();
        if (anySupplier != null) {
          effectiveSupplierId = anySupplier.id;
        } else {
          effectiveSupplierId = await _db.into(_db.suppliers).insert(
            SuppliersCompanion.insert(name: 'مورد عام', contactInfo: const Value('')),
          );
        }
      }

      // 3. توليد رقم فاتورة الشراء
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final todayCount = await (_db.select(_db.purchases)
            ..where((p) => p.createdAt.isBiggerOrEqualValue(startOfDay)))
          .get()
          .then((rows) => rows.length);
      final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final seq = (todayCount + 1).toString().padLeft(4, '0');
      final purchaseNumber = 'PUR-$datePart-$seq';

      final totalAmount = purchasePrice * quantity;

      // 4. إنشاء فاتورة المشتريات
      final purchaseId = await _db.into(_db.purchases).insert(
        PurchasesCompanion.insert(
          purchaseNumber: purchaseNumber,
          supplierInvoiceRef: Value(batchNumber != null && batchNumber.isNotEmpty ? 'توريد دفعة $batchNumber' : 'توريد مخزون'),
          supplierId: effectiveSupplierId,
          subTotal: Value(totalAmount),
          taxAmount: const Value(0.0),
          totalAmount: totalAmount,
          paidAmount: Value(totalAmount),
          paymentMethod: const Value('نقدي'),
        ),
      );

      // 5. إنشاء عناصر فاتورة المشتريات
      await _db.into(_db.purchaseItems).insert(
        PurchaseItemsCompanion.insert(
          purchaseId: purchaseId,
          medicineId: medicineId,
          batchId: batchId,
          quantity: quantity,
          unitCost: purchasePrice,
          subtotal: totalAmount,
          taxRate: const Value(0.0),
          taxAmount: const Value(0.0),
          total: Value(totalAmount),
        ),
      );
    });

    // 6. تسجيل القيد المحاسبي
    try {
      final inventoryAccId = await _glRepo.getAccountIdByCode('1102');
      final cashAccId = await _glRepo.getAccountIdByCode('1101');
      if (inventoryAccId != null && cashAccId != null) {
        final totalAmount = purchasePrice * quantity;
        await _glRepo.postJournalEntry(
          referenceNumber: 'JE-REC-$medicineId-${DateTime.now().millisecondsSinceEpoch}',
          date: DateTime.now(),
          description: 'توريد مخزون صنف $medicineId',
          source: 'Purchases',
          sourceId: medicineId,
          createdBy: 1,
          lines: [
            JournalEntryLineEntity(
              id: 0, journalEntryId: 0, accountId: inventoryAccId, accountName: '',
              debit: totalAmount, credit: 0, description: 'توريد مخزون',
            ),
            JournalEntryLineEntity(
              id: 0, journalEntryId: 0, accountId: cashAccId, accountName: '',
              debit: 0, credit: totalAmount, description: 'دفع توريد مخزون',
            ),
          ],
        );
      }
    } catch (_) {}
  }

  @override
  Future<void> writeOffStock({
    required int medicineId,
    required int quantity,
    required String reason,
    String? notes,
    int? recordedBy,
  }) async {
    if (quantity <= 0) {
      throw Exception('الكمية يجب أن تكون أكبر من صفر');
    }

    await _db.transaction(() async {
      var remainingToDeduct = quantity;
      double totalLostCost = 0;

      final availableBatches = await (_db.select(_db.batches)
            ..where((b) => b.medicineId.equals(medicineId) & b.quantity.isBiggerThanValue(0)))
          .get();

      // FEFO: الأقرب انتهاءً أولًا
      availableBatches.sort((a, b) {
        if (a.expiryDate == null && b.expiryDate == null) return 0;
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return a.expiryDate!.compareTo(b.expiryDate!);
      });

      for (final batch in availableBatches) {
        if (remainingToDeduct <= 0) break;
        final takeFromBatch = remainingToDeduct < batch.quantity ? remainingToDeduct : batch.quantity;

        await (_db.update(_db.batches)..where((b) => b.id.equals(batch.id)))
            .write(BatchesCompanion(
          quantity: Value(batch.quantity - takeFromBatch),
        ));

        totalLostCost += (takeFromBatch * batch.purchasePrice!);
        remainingToDeduct -= takeFromBatch;
      }

      if (remainingToDeduct > 0) {
        throw Exception('الكمية المتوفرة لا تكفي للإتلاف.');
      }

      // تسجيل حركة الإتلاف
      final writeOffId = await _db.into(_db.inventoryWriteOffs).insert(
            InventoryWriteOffsCompanion.insert(
              medicineId: medicineId,
              quantity: quantity.toDouble(), // Assuming schema expects RealColumn
              reason: reason,
              notes: Value(notes),
              recordedBy: Value(recordedBy),
            ),
          );

      // تسجيل القيد المحاسبي للإتلاف (تخفيض المخزون وإثبات الخسارة)
      if (totalLostCost > 0) {
        try {
          final expAccId = await _glRepo.getAccountIdByCode('5102'); // General Expense (or specific write-off)
          final invAccId = await _glRepo.getAccountIdByCode('1102'); // Inventory
          
          if (expAccId != null && invAccId != null) {
             await _glRepo.postJournalEntry(
                referenceNumber: 'WO-$writeOffId',
                date: DateTime.now(),
                description: 'إتلاف مخزون (السبب: $reason) $notes',
                source: 'InventoryWriteOff',
                sourceId: writeOffId,
                createdBy: recordedBy ?? 1,
                lines: [
                  JournalEntryLineEntity(
                    id: 0, journalEntryId: 0, accountId: expAccId, accountName: '',
                    debit: totalLostCost, credit: 0, description: 'مصروف إتلاف/خسارة بضاعة',
                  ),
                  JournalEntryLineEntity(
                    id: 0, journalEntryId: 0, accountId: invAccId, accountName: '',
                    debit: 0, credit: totalLostCost, description: 'تخفيض المخزون',
                  ),
                ],
             );
          }
        } catch(e) {
          // ignore
        }
      }
    });
  }

  @override
  Future<void> reconcileStock({
    required int medicineId,
    required double actualQuantity,
    required double systemQuantity,
    String? note,
    int? userId,
  }) async {
    final difference = actualQuantity - systemQuantity;
    if (difference == 0) return;

    await _db.transaction(() async {
      // 1. Record the reconciliation
      await _db.into(_db.inventoryReconciliations).insert(
            InventoryReconciliationsCompanion.insert(
              medicineId: medicineId,
              actualQuantity: actualQuantity,
              systemQuantity: systemQuantity,
              difference: difference,
              note: Value(note),
              userId: Value(userId),
            ),
          );

      // 2. Adjust Batches
      if (difference > 0) {
        // Surplus: Add to a new or existing batch without expiry date for now
        await receiveStock(
          medicineId: medicineId,
          quantity: difference.toInt(),
          purchasePrice: 0, // This is a surplus, we might not know cost, so 0 or average cost
        );
      } else {
        // Deficit: Write it off
        await writeOffStock(
          medicineId: medicineId,
          quantity: difference.abs().toInt(),
          reason: 'عجز تسوية جردية',
          notes: note,
          recordedBy: userId,
        );
      }
    });
  }

  @override
  Future<void> deleteStockRecords(int medicineId) async {
    await (_db.update(_db.batches)..where((b) => b.medicineId.equals(medicineId)))
        .write(const BatchesCompanion(quantity: Value(0)));
  }

  @override
  Future<void> deleteSingleBatch(int batchId) async {
    // تصفير كمية الدفعة المحددة فقط (تاريخ وصنف محدد) دون المساس بباقي دفعات وتواريخ الصنف
    await (_db.update(_db.batches)..where((b) => b.id.equals(batchId)))
        .write(const BatchesCompanion(quantity: Value(0)));
  }
}
