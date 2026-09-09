import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../accounting/domain/repositories/general_ledger_repository.dart';
import '../../../accounting/domain/entities/accounting_entities.dart';

abstract class SuppliersDataSource {
  Future<List<SupplierRow>> getAll();
  Future<SupplierRow> create({
    required String name,
    String? contactInfo,
    String? notes,
  });
  Future<void> update(int id, String newName);
  Future<void> archive(int id);
  Future<List<Map<String, dynamic>>> getPharmacyDebts();
  Future<void> recordVendorPayment({
    required int supplierId,
    required double amount,
    required String paymentMethod,
    String? notes,
  });
  
  Future<List<PurchaseRow>> getSupplierPurchases(int supplierId);
  Future<List<MedicineRow>> getSupplierMedicines(int supplierId);
}

class SuppliersDataSourceImpl implements SuppliersDataSource {
  final AppDatabase _db;
  final GeneralLedgerRepository _glRepo;
  SuppliersDataSourceImpl(this._db, this._glRepo);

  @override
  Future<List<SupplierRow>> getAll() {
    return (_db.select(_db.suppliers)
          ..where((s) => s.isActive.equals(true))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .get();
  }

  @override
  Future<SupplierRow> create({
    required String name,
    String? contactInfo,
    String? notes,
  }) async {
    final id = await _db.into(_db.suppliers).insert(
          SuppliersCompanion.insert(
            name: name.trim(),
            contactInfo: Value(contactInfo),
            notes: Value(notes),
          ),
        );
        
    // Sync with General Ledger: Create a specific sub-account for this supplier under '2101'
    try {
      final parentApId = await _glRepo.getAccountIdByCode('2101');
      if (parentApId != null) {
        await _glRepo.addAccount(
          code: '2101-$id',
          name: 'مورد: ${name.trim()}',
          type: 'Liability',
          parentId: parentApId,
        );
      }
    } catch (e) {
      print('Error creating GL account for supplier $id: $e');
    }

    return (_db.select(_db.suppliers)..where((s) => s.id.equals(id))).getSingle();
  }

  @override
  Future<void> update(int id, String newName) async {
    await (_db.update(_db.suppliers)..where((s) => s.id.equals(id))).write(
      SuppliersCompanion(name: Value(newName.trim())),
    );
  }

  @override
  Future<void> archive(int id) async {
    await (_db.update(_db.suppliers)..where((s) => s.id.equals(id))).write(
      const SuppliersCompanion(isActive: Value(false)),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPharmacyDebts() async {
    // Total owed per supplier from purchases
    final purchasesQuery = _db.select(_db.purchases).join([
      innerJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchases.supplierId)),
    ]);
    
    final debts = <int, Map<String, dynamic>>{};
    
    final rows = await purchasesQuery.get();
    for (final row in rows) {
      final p = row.readTable(_db.purchases);
      final s = row.readTable(_db.suppliers);
      
      if (!debts.containsKey(s.id)) {
        debts[s.id] = {
          'supplierId': s.id,
          'supplierName': s.name,
          'totalAmountOwed': 0.0,
          'totalAmountPaid': 0.0,
          'remainingDebt': 0.0,
        };
      }
      
      debts[s.id]!['totalAmountOwed'] += p.totalAmount;
      debts[s.id]!['totalAmountPaid'] += p.paidAmount;
    }
    
    // Process remaining debt
    for (final key in debts.keys) {
      debts[key]!['remainingDebt'] = debts[key]!['totalAmountOwed'] - debts[key]!['totalAmountPaid'];
    }
    
    // Only return suppliers where remainingDebt > 0
    return debts.values.where((d) => d['remainingDebt'] > 0).toList();
  }

  @override
  Future<void> recordVendorPayment({
    required int supplierId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw Exception('لا يمكن تسديد مبلغ سالب أو صفر');
    }

    final paymentId = await _db.transaction(() async {
      final pid = await _db.into(_db.vendorPayments).insert(
        VendorPaymentsCompanion.insert(
          supplierId: supplierId,
          amount: amount,
          paymentMethod: Value(paymentMethod),
          notes: Value(notes),
          createdAt: Value(DateTime.now()),
        ),
      );

      // توزيع المبلغ المسدد على فواتير الشراء غير المسددة بالكامل لهذا المورد (FIFO)
      var remainingToAllocate = amount;
      final unpaidPurchases = await (_db.select(_db.purchases)
            ..where((p) => p.supplierId.equals(supplierId) & p.paidAmount.isSmallerThan(p.totalAmount))
            ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
          .get();

      for (final purchase in unpaidPurchases) {
        if (remainingToAllocate <= 0) break;
        final unpaidBalance = purchase.totalAmount - purchase.paidAmount;
        final payForThisInvoice = remainingToAllocate < unpaidBalance ? remainingToAllocate : unpaidBalance;
        
        await (_db.update(_db.purchases)..where((p) => p.id.equals(purchase.id))).write(
          PurchasesCompanion(
            paidAmount: Value(purchase.paidAmount + payForThisInvoice),
          ),
        );

        remainingToAllocate -= payForThisInvoice;
      }

      return pid;
    });

    // القيود المحاسبية
    try {
      final isGoodsReturn = paymentMethod == 'مرتجع أدوية';
      final creditAccCode = isGoodsReturn ? '1104' : (paymentMethod == 'محفظة إلكترونية' ? '1102' : '1101');
      final creditAccId = await _glRepo.getAccountIdByCode(creditAccCode) ?? await _glRepo.getAccountIdByCode('1101');
      final apAccId = await _glRepo.getAccountIdByCode('2101-$supplierId') ?? await _glRepo.getAccountIdByCode('2101');
      
      if (creditAccId != null && apAccId != null) {
        await _glRepo.postJournalEntry(
          referenceNumber: 'V-PAY-$paymentId',
          date: DateTime.now(),
          description: isGoodsReturn ? 'خصم مديونية المورد مقابل مرتجع بضاعة وأدوية' : 'سداد دفعة للمورد $supplierId',
          source: 'VendorPayment',
          sourceId: paymentId,
          createdBy: 1,
          lines: [
            JournalEntryLineEntity(
              id: 0, journalEntryId: 0, accountId: apAccId, accountName: '',
              debit: amount, credit: 0, description: 'تخفيض مديونية المورد',
            ),
            JournalEntryLineEntity(
              id: 0, journalEntryId: 0, accountId: creditAccId, accountName: '',
              debit: 0, credit: amount, description: isGoodsReturn ? 'إخراج بضاعة وأدوية مرتجعة للمورد' : 'صرف لسداد المورد',
            ),
          ],
        );
      }
    } catch (e) {
      print('Error posting vendor payment journal entry: $e');
    }
  }

  @override
  Future<List<PurchaseRow>> getSupplierPurchases(int supplierId) {
    return (_db.select(_db.purchases)
          ..where((p) => p.supplierId.equals(supplierId))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .get();
  }

  @override
  Future<List<MedicineRow>> getSupplierMedicines(int supplierId) async {
    final query = _db.select(_db.medicines).join([
      innerJoin(
        _db.purchaseItems,
        _db.purchaseItems.medicineId.equalsExp(_db.medicines.id),
      ),
      innerJoin(
        _db.purchases,
        _db.purchases.id.equalsExp(_db.purchaseItems.purchaseId),
      ),
    ])
      ..where(_db.purchases.supplierId.equals(supplierId));

    final rows = await query.get();
    
    // Use a Set or Map to keep only unique medicines
    final uniqueMedicines = <int, MedicineRow>{};
    for (final row in rows) {
      final med = row.readTable(_db.medicines);
      uniqueMedicines[med.id] = med;
    }
    
    return uniqueMedicines.values.toList();
  }
}
