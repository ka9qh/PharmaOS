import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:pharmaos/core/database/app_database.dart';
import 'package:pharmaos/core/security/audit_logger.dart';
import 'package:pharmaos/features/accounting/data/repositories/general_ledger_repository_impl.dart';
import 'package:pharmaos/features/doctors/data/repositories/doctors_repository_impl.dart';
import 'package:pharmaos/features/prescriptions/data/repositories/prescriptions_repository_impl.dart';
import 'package:pharmaos/features/inventory/data/datasources/inventory_datasource.dart';
import 'package:pharmaos/features/inventory/data/repositories/inventory_repository_impl.dart';

void main() {
  late AppDatabase db;
  late DoctorsRepositoryImpl doctorsRepo;
  late PrescriptionsRepositoryImpl prescriptionsRepo;
  late InventoryRepositoryImpl inventoryRepo;
  late InventoryDataSourceImpl inventoryDataSource;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final glRepo = GeneralLedgerRepositoryImpl(db);
    final auditLogger = AuditLogger(db);
    doctorsRepo = DoctorsRepositoryImpl(db);
    prescriptionsRepo = PrescriptionsRepositoryImpl(db);
    inventoryDataSource = InventoryDataSourceImpl(db, glRepo);
    inventoryRepo = InventoryRepositoryImpl(inventoryDataSource, auditLogger);
  });

  tearDown(() async {
    await db.close();
  });

  test('1. Test Doctors management (Add, Search, Update, Delete)', () async {
    // Add doctor
    final docId = await doctorsRepo.add(
      DoctorsCompanion.insert(
        name: 'د. أحمد الشامي',
        specialty: const drift.Value('باطنية وجهاز هضمي'),
        phone: const drift.Value('777123456'),
        clinicAddress: const drift.Value('صنعاء - شارع الزبيري'),
      ),
    );
    expect(docId, isPositive);

    // Search doctor
    var results = await doctorsRepo.getAll(searchQuery: 'الشامي');
    expect(results.length, 1);
    expect(results.first.name, 'د. أحمد الشامي');

    var searchBySpecialty = await doctorsRepo.getAll(searchQuery: 'باطنية');
    expect(searchBySpecialty.length, 1);

    // Update doctor
    final doc = await doctorsRepo.getById(docId);
    await doctorsRepo.update(doc.copyWith(phone: const drift.Value('777999888')));
    final updated = await doctorsRepo.getById(docId);
    expect(updated.phone, '777999888');

    // Delete doctor
    await doctorsRepo.delete(docId);
    final emptyResults = await doctorsRepo.getAll();
    expect(emptyResults.isEmpty, isTrue);
  });

  test('2. Test Prescriptions management (Add, Search, Customer/Doctor linkage)', () async {
    // Create Doctor & Customer
    final docId = await doctorsRepo.add(
      DoctorsCompanion.insert(
        name: 'د. سارة اليماني',
        specialty: const drift.Value('أطفال'),
      ),
    );

    final customerId = await db.into(db.customers).insert(
      CustomersCompanion.insert(
        name: 'محمد عبدالله',
        phone: const drift.Value('770000111'),
      ),
    );

    // Add Prescription
    final preId = await prescriptionsRepo.add(
      PrescriptionsCompanion.insert(
        prescriptionNumber: const drift.Value('RX-2026-001'),
        diagnosis: const drift.Value('التهاب الحلق واللوزتين'),
        notes: const drift.Value('أوجمنتين 625 مجم كل 12 ساعة + باراسيتامول'),
        customerId: drift.Value(customerId),
        doctorId: drift.Value(docId),
        issueDate: drift.Value(DateTime.now()),
      ),
    );
    expect(preId, isPositive);

    // Search Prescriptions
    var searchByNumber = await prescriptionsRepo.getAll(searchQuery: 'RX-2026');
    expect(searchByNumber.length, 1);
    expect(searchByNumber.first.diagnosis, 'التهاب الحلق واللوزتين');

    var filterByCustomer = await prescriptionsRepo.getAll(customerId: customerId);
    expect(filterByCustomer.length, 1);

    var filterByDoctor = await prescriptionsRepo.getAll(doctorId: docId);
    expect(filterByDoctor.length, 1);

    // Update Prescription
    final pre = await prescriptionsRepo.getById(preId);
    await prescriptionsRepo.update(pre.copyWith(diagnosis: const drift.Value('التهاب حاد')));
    final updatedPre = await prescriptionsRepo.getById(preId);
    expect(updatedPre.diagnosis, 'التهاب حاد');

    // Delete Prescription
    await prescriptionsRepo.delete(preId);
    final allPres = await prescriptionsRepo.getAll();
    expect(allPres.isEmpty, isTrue);
  });

  test('3. Test Inventory Reconciliation (Surplus & Deficit adjustment)', () async {
    // Add Medicine
    final medId = await db.into(db.medicines).insert(
      MedicinesCompanion.insert(
        sku: 'MED-TEST-001',
        barcode: 'BAR-TEST-001',
        nameAr: 'أموكسيسيلين 500 مجم',
        purchasePrice: 800.0,
        sellingPrice: 1200.0,
      ),
    );

    // Initial stock overview (0 quantity before receiving, so 0 batches)
    var overview = await inventoryRepo.getStockOverview();
    expect(overview.length, 0);

    // Receive 10 units
    await inventoryRepo.receiveStock(
      medicineId: medId,
      quantity: 10,
      purchasePrice: 800.0,
      expiryDate: DateTime.now().add(const Duration(days: 365)),
    );

    var stock = await inventoryRepo.getAvailableQuantity(medId);
    expect(stock, 10);

    // Reconcile with Deficit (Actual count = 8, System count = 10) -> Deficit 2
    await inventoryRepo.reconcileStock(
      medicineId: medId,
      actualQuantity: 8,
      systemQuantity: 10,
      note: 'عجز جردي 2 حبات تالفة',
    );

    var afterDeficit = await inventoryRepo.getAvailableQuantity(medId);
    expect(afterDeficit, 8);

    // Reconcile with Surplus (Actual count = 12, System count = 8) -> Surplus 4
    await inventoryRepo.reconcileStock(
      medicineId: medId,
      actualQuantity: 12,
      systemQuantity: 8,
      note: 'فائض جردي 4 حبات تم العثور عليها',
    );

    var afterSurplus = await inventoryRepo.getAvailableQuantity(medId);
    expect(afterSurplus, 12);
  });
}
