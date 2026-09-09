import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:pharmaos/core/database/app_database.dart';
import 'package:pharmaos/features/inventory/data/datasources/inventory_datasource.dart';
import 'package:pharmaos/features/sales/data/datasources/sales_datasource.dart';
import 'package:pharmaos/features/sales/domain/entities/sales_entity.dart';
import 'package:pharmaos/features/accounting/data/repositories/general_ledger_repository_impl.dart';

// Fake accounting repository for testing
class FakeGLRepo extends GeneralLedgerRepositoryImpl {
  FakeGLRepo(AppDatabase db) : super(db);
  @override
  Future<void> recordTransaction({
    required double amount,
    required int debitAccountId,
    required int creditAccountId,
    required String reference,
    required String description,
    required int userId,
    DateTime? date,
  }) async {}
}

void main() {
  late AppDatabase db;
  late InventoryDataSourceImpl inventoryDs;
  late SalesDataSourceImpl salesDs;
  
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    inventoryDs = InventoryDataSourceImpl(db, FakeGLRepo(db));
    salesDs = SalesDataSourceImpl(db, FakeGLRepo(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('FEFO and Multi-Unit Sales Deduction End-to-End', () async {
    // 1. Create a medicine (Unit: Pack, QtyPerPack: 10, Strip: 10)
    final medicineId = await db.into(db.medicines).insert(
      MedicinesCompanion.insert(
        sku: '123',
        barcode: '123',
        nameAr: 'بانادول تست',
        unit: const drift.Value('باكت'),
        purchasePrice: 1000,
        sellingPrice: 1200,
        reorderLevel: const drift.Value(5),
        isActive: const drift.Value(true),
        medicineType: const drift.Value(1),
        qtyPerPack: const drift.Value(10), // Pack = 10 strips
        qtyPerStrip: const drift.Value(10), // Strip = 10 pills
      )
    );
    // Base unit is pill. Pack = 100 pills. Strip = 10 pills.
    
    // 2. Add batches
    // Batch 1: Expires in 2026-12-01, Qty: 50 (base units)
    await db.into(db.batches).insert(
      BatchesCompanion.insert(
        medicineId: medicineId,
        purchasePrice: 1000,
        batchNumber: const drift.Value('B1'),
        expiryDate: drift.Value(DateTime(2026, 12, 1)),
        quantity: 50,
      )
    );
    // Batch 2: Expires in 2026-10-01 (Earlier expiry), Qty: 150
    await db.into(db.batches).insert(
      BatchesCompanion.insert(
        medicineId: medicineId,
        purchasePrice: 1000,
        batchNumber: const drift.Value('B2'),
        expiryDate: drift.Value(DateTime(2026, 10, 1)),
        quantity: 150,
      )
    );

    // 3. Test FEFO Deduction: Sell 100 units (1 Pack) with batchId = null
    // It should take all 100 from Batch 2 since it expires earlier (150 - 100 = 50 left).
    await salesDs.createSaleTransactional(
      cashierId: 1,
      discount: 0,
      paymentMethod: 'نقدي',
      items: [
        CartLineInput(
          medicineId: medicineId,
          medicineName: 'بانادول تست',
          quantity: 100, // 100 base units (1 Pack)
          unitPrice: 1200,
          unitName: 'باكت',
          conversionFactor: 100,
          selectedQuantity: 1,
        )
      ],
    );
    
    final batchesAfterFefo = await db.select(db.batches).get();
    
    // Batch 2 should be 50, Batch 1 should be 50
    expect(batchesAfterFefo.firstWhere((b) => b.batchNumber == 'B2').quantity, 50);
    expect(batchesAfterFefo.firstWhere((b) => b.batchNumber == 'B1').quantity, 50);

    // 4. Test Multi-Batch FEFO Deduction: Sell 80 units
    // Should take remaining 50 from Batch 2, then 30 from Batch 1.
    await salesDs.createSaleTransactional(
      cashierId: 1,
      discount: 0,
      paymentMethod: 'نقدي',
      items: [
        CartLineInput(
          medicineId: medicineId,
          medicineName: 'بانادول تست',
          quantity: 80, // 80 base units
          unitPrice: 12,
          unitName: 'حبه',
          conversionFactor: 1,
          selectedQuantity: 80,
        )
      ],
    );
    
    final batchesAfterMulti = await db.select(db.batches).get();
    // Batch 2 should be 0, Batch 1 should be 20
    expect(batchesAfterMulti.firstWhere((b) => b.batchNumber == 'B2').quantity, 0);
    expect(batchesAfterMulti.firstWhere((b) => b.batchNumber == 'B1').quantity, 20);
    
    // 5. Test Specific Batch Deduction
    // Add a new batch explicitly
    final specificBatchId = await db.into(db.batches).insert(
      BatchesCompanion.insert(
        medicineId: medicineId,
        purchasePrice: 1000,
        batchNumber: const drift.Value('B3'),
        expiryDate: drift.Value(DateTime(2027, 1, 1)),
        quantity: 200,
      )
    );
    
    await salesDs.createSaleTransactional(
      cashierId: 1,
      discount: 0,
      paymentMethod: 'نقدي',
      items: [
        CartLineInput(
          medicineId: medicineId,
          medicineName: 'بانادول تست',
          quantity: 10, // 10 base units (1 Strip)
          unitPrice: 120,
          unitName: 'شريط',
          conversionFactor: 10,
          selectedQuantity: 1,
          batchId: specificBatchId, // Force deduction from B3
        )
      ],
    );
    
    final batchesAfterSpecific = await db.select(db.batches).get();
    
    // B3 should be 190 (200 - 10), B1 should remain 20
    expect(batchesAfterSpecific.firstWhere((b) => b.batchNumber == 'B3').quantity, 190);
    expect(batchesAfterSpecific.firstWhere((b) => b.batchNumber == 'B1').quantity, 20);
  });
}
