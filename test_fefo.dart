import 'dart:io';
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

void main() async {
  print('Starting FEFO Verification...');
  
  // Initialize in-memory database
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  
  try {
    final inventoryDs = InventoryDataSourceImpl(db, FakeGLRepo(db));
    final salesDs = SalesDataSourceImpl(db, FakeGLRepo(db));
    
    // 1. Create a medicine (Unit: Pack, QtyPerPack: 10, Strip: 10)
    final medicineId = await db.into(db.medicines).insert(
      MedicinesCompanion.insert(
        nameAr: 'بانادول تست',
        unit: 'باكت',
        purchasePrice: 1000,
        sellingPrice: 1200,
        reorderLevel: 5,
        isActive: const drift.Value(true),
        medicineType: const drift.Value(1),
        qtyPerPack: const drift.Value(10),
        qtyPerStrip: const drift.Value(10),
      )
    );
    print('Medicine created with ID: $medicineId');

    // 2. Add batches
    // Batch 1: Expires in 2026-12-01, Qty: 5 (base units)
    await db.into(db.batches).insert(
      BatchesCompanion.insert(
        medicineId: medicineId,
        batchNumber: const drift.Value('B1'),
        expiryDate: drift.Value(DateTime(2026, 12, 1)),
        quantity: 5,
      )
    );
    // Batch 2: Expires in 2026-10-01 (Earlier expiry), Qty: 15
    await db.into(db.batches).insert(
      BatchesCompanion.insert(
        medicineId: medicineId,
        batchNumber: const drift.Value('B2'),
        expiryDate: drift.Value(DateTime(2026, 10, 1)),
        quantity: 15,
      )
    );
    
    print('Batches added. Available Qty: ${await inventoryDs.getAvailableQuantity(medicineId)}');

    // 3. Test FEFO Deduction: Sell 10 units with batchId = null
    // It should take all 10 from Batch 2 since it expires earlier (15 - 10 = 5 left).
    print('\\n--- Test 1: FEFO Deduction ---');
    await salesDs.createSale(
      cashierId: 1,
      subtotal: 100,
      totalAmount: 100,
      discount: 0,
      paymentMethod: 'نقدي',
      items: [
        CartLineInput(
          medicineId: medicineId,
          medicineName: 'بانادول تست',
          quantity: 10, // 10 base units
          unitPrice: 100,
          unitName: 'حبه',
          conversionFactor: 1,
          selectedQuantity: 10,
        )
      ],
    );
    
    final batchesAfterFefo = await db.select(db.batches).get();
    for (var b in batchesAfterFefo) {
      print('Batch ${b.batchNumber}: Qty ${b.quantity}');
    }
    
    // Batch 2 should be 5, Batch 1 should be 5
    if (batchesAfterFefo.firstWhere((b) => b.batchNumber == 'B2').quantity != 5) {
      throw Exception('FEFO failed: Batch 2 qty is not 5');
    }
    if (batchesAfterFefo.firstWhere((b) => b.batchNumber == 'B1').quantity != 5) {
      throw Exception('FEFO failed: Batch 1 qty is not 5');
    }
    print('FEFO Deduction SUCCESS!');

    // 4. Test Multi-Batch FEFO Deduction: Sell 8 units
    // Should take remaining 5 from Batch 2, then 3 from Batch 1.
    print('\\n--- Test 2: Multi-Batch FEFO Deduction ---');
    await salesDs.createSale(
      cashierId: 1,
      subtotal: 80,
      totalAmount: 80,
      discount: 0,
      paymentMethod: 'نقدي',
      items: [
        CartLineInput(
          medicineId: medicineId,
          medicineName: 'بانادول تست',
          quantity: 8, // 8 base units
          unitPrice: 100,
          unitName: 'حبه',
          conversionFactor: 1,
          selectedQuantity: 8,
        )
      ],
    );
    
    final batchesAfterMulti = await db.select(db.batches).get();
    for (var b in batchesAfterMulti) {
      print('Batch ${b.batchNumber}: Qty ${b.quantity}');
    }
    // Batch 2 should be 0, Batch 1 should be 2
    if (batchesAfterMulti.firstWhere((b) => b.batchNumber == 'B2').quantity != 0) {
      throw Exception('Multi-Batch FEFO failed: Batch 2 qty is not 0');
    }
    if (batchesAfterMulti.firstWhere((b) => b.batchNumber == 'B1').quantity != 2) {
      throw Exception('Multi-Batch FEFO failed: Batch 1 qty is not 2');
    }
    print('Multi-Batch FEFO SUCCESS!');
    
    // 5. Test Specific Batch Deduction
    print('\\n--- Test 3: Specific Batch Deduction ---');
    // Add a new batch explicitly
    final specificBatchId = await db.into(db.batches).insert(
      BatchesCompanion.insert(
        medicineId: medicineId,
        batchNumber: const drift.Value('B3'),
        expiryDate: drift.Value(DateTime(2027, 1, 1)),
        quantity: 20,
      )
    );
    
    await salesDs.createSale(
      cashierId: 1,
      subtotal: 50,
      totalAmount: 50,
      discount: 0,
      paymentMethod: 'نقدي',
      items: [
        CartLineInput(
          medicineId: medicineId,
          medicineName: 'بانادول تست',
          quantity: 15, // 15 base units
          unitPrice: 100,
          unitName: 'حبه',
          conversionFactor: 1,
          selectedQuantity: 15,
          batchId: specificBatchId, // Force deduction from B3
        )
      ],
    );
    
    final batchesAfterSpecific = await db.select(db.batches).get();
    for (var b in batchesAfterSpecific) {
      print('Batch ${b.batchNumber}: Qty ${b.quantity}');
    }
    
    // B3 should be 5, B1 should remain 2
    if (batchesAfterSpecific.firstWhere((b) => b.batchNumber == 'B3').quantity != 5) {
      throw Exception('Specific Batch Deduction failed: B3 qty is not 5');
    }
    if (batchesAfterSpecific.firstWhere((b) => b.batchNumber == 'B1').quantity != 2) {
      throw Exception('Specific Batch Deduction failed: B1 qty changed');
    }
    print('Specific Batch Deduction SUCCESS!');
    
    print('\\nAll tests passed successfully end-to-end!');
    exit(0);
  } catch (e, st) {
    print('ERROR: $e');
    print(st);
    exit(1);
  }
}
