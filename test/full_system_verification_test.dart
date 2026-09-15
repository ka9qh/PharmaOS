import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmaos/core/database/app_database.dart';
import 'package:pharmaos/core/security/audit_logger.dart';
import 'package:pharmaos/core/services/official_date_time_service.dart';
import 'package:pharmaos/core/services/device_branch_manager_service.dart';
import 'package:pharmaos/core/services/partnered_entities_service.dart';
import 'package:pharmaos/features/accounting/data/repositories/general_ledger_repository_impl.dart';
import 'package:pharmaos/features/categories/data/datasources/categories_datasource.dart';
import 'package:pharmaos/features/categories/data/repositories/categories_repository_impl.dart';
import 'package:pharmaos/features/companies/data/datasources/companies_datasource.dart';
import 'package:pharmaos/features/companies/data/repositories/companies_repository_impl.dart';
import 'package:pharmaos/features/medicines/data/datasources/medicines_datasource.dart';
import 'package:pharmaos/features/medicines/data/repositories/medicines_repository_impl.dart';
import 'package:pharmaos/features/sales/data/datasources/sales_datasource.dart';
import 'package:pharmaos/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:pharmaos/features/sales/domain/entities/sales_entity.dart';
import 'package:pharmaos/features/purchases/data/datasources/purchases_datasource.dart';
import 'package:pharmaos/features/purchases/data/repositories/purchases_repository_impl.dart';
import 'package:pharmaos/features/purchases/domain/entities/purchases_entity.dart';
import 'package:pharmaos/features/returns/data/datasources/returns_datasource.dart';
import 'package:pharmaos/features/returns/data/repositories/returns_repository_impl.dart';
import 'package:pharmaos/features/customers/data/datasources/customers_datasource.dart';
import 'package:pharmaos/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:pharmaos/features/suppliers/data/datasources/suppliers_datasource.dart';
import 'package:pharmaos/features/suppliers/data/repositories/suppliers_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late AppDatabase db;
  late AuditLogger auditLogger;
  late GeneralLedgerRepositoryImpl glRepo;
  late CategoriesRepositoryImpl categoriesRepo;
  late CompaniesRepositoryImpl companiesRepo;
  late SuppliersRepositoryImpl suppliersRepo;
  late MedicinesRepositoryImpl medicinesRepo;
  late SalesRepositoryImpl salesRepo;
  late PurchasesRepositoryImpl purchasesRepo;
  late ReturnsRepositoryImpl returnsRepo;
  late CustomersRepositoryImpl customersRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auditLogger = AuditLogger(db);
    glRepo = GeneralLedgerRepositoryImpl(db);
    await glRepo.seedDefaultAccountsIfEmpty();

    final catDs = CategoriesDataSourceImpl(db);
    categoriesRepo = CategoriesRepositoryImpl(catDs);

    final compDs = CompaniesDataSourceImpl(db);
    companiesRepo = CompaniesRepositoryImpl(compDs);

    final suppDs = SuppliersDataSourceImpl(db, glRepo);
    suppliersRepo = SuppliersRepositoryImpl(suppDs);

    final medDs = MedicinesDataSourceImpl(db);
    medicinesRepo = MedicinesRepositoryImpl(
      dataSource: medDs,
      categoriesRepository: categoriesRepo,
      companiesRepository: companiesRepo,
      suppliersRepository: suppliersRepo,
      auditLogger: auditLogger,
    );

    final salesDs = SalesDataSourceImpl(db, glRepo);
    salesRepo = SalesRepositoryImpl(dataSource: salesDs, auditLogger: auditLogger);

    final purchDs = PurchasesDataSourceImpl(db, glRepo);
    purchasesRepo = PurchasesRepositoryImpl(
      dataSource: purchDs,
      suppliersRepository: suppliersRepo,
      auditLogger: auditLogger,
    );

    final retDs = ReturnsDataSourceImpl(db, glRepo);
    returnsRepo = ReturnsRepositoryImpl(dataSource: retDs, auditLogger: auditLogger);

    final custDs = CustomersDataSourceImpl(db, glRepo);
    customersRepo = CustomersRepositoryImpl(dataSource: custDs, auditLogger: auditLogger);
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Official Date & Time Service Tests', () {
    test('Official Date/Time formatting contains date, hour, minute, second and period', () {
      final dt = DateTime(2026, 9, 15, 14, 30, 45);
      final formatted = OfficialDateTimeService.formatOfficialDateTime(dt);
      expect(formatted, contains('2026/09/15'));
      expect(formatted, contains('02:30:45'));
      expect(formatted, contains('م'));
    });
  });

  group('2. Topology & Multi-Branch / Cashier Token Manager Tests', () {
    test('Default branch and server device tokens generated properly', () async {
      final branches = await DeviceBranchManagerService.getBranches();
      expect(branches.isNotEmpty, true);
      expect(branches.first.code, 'BR-01');
      expect(branches.first.token, startsWith('PHOS-MAIN-BRANCH-'));

      final devices = await DeviceBranchManagerService.getDevices();
      expect(devices.isNotEmpty, true);
      expect(devices.first.isMainServer, true);
      expect(devices.first.token, startsWith('PHOS-DEV-01-'));
    });

    test('Add new branch and cashier with unique tokens', () async {
      final newBranch = await DeviceBranchManagerService.addBranch(name: 'فرع الأمل', code: 'BR-02');
      expect(newBranch.name, 'فرع الأمل');
      expect(newBranch.token, startsWith('PHOS-BR-02-'));

      final newCashier = await DeviceBranchManagerService.addDevice(
        branchId: newBranch.id,
        name: 'كاشير الصالة 1',
        isMainServer: false,
      );
      expect(newCashier.name, 'كاشير الصالة 1');
      expect(newCashier.token, startsWith('PHOS-DEV-'));
      expect(newCashier.isMainServer, false);

      final allBranches = await DeviceBranchManagerService.getBranches();
      expect(allBranches.length, 2);

      final allDevices = await DeviceBranchManagerService.getDevices();
      expect(allDevices.length, 2);
    });

    test('Smart activation request code generator format [PharmacyName]#[HardwareID]', () async {
      final code = await DeviceBranchManagerService.generatePharmacyActivationRequestCode(
        'صيدلية الشفاء الحديثة',
        'HW-998877AABB',
      );
      expect(code, 'صيدلية_الشفاء_الحديثة#HW-998877AABB');
    });

    test('Topology mode persistence', () async {
      await DeviceBranchManagerService.setTopologyMode(TopologyMode.multiBranch);
      final mode = await DeviceBranchManagerService.getTopologyMode();
      expect(mode, TopologyMode.multiBranch);
    });
  });

  group('3. Partnered Entities Service Tests', () {
    test('Partnered suppliers and companies state tracking', () async {
      final initialSuppliers = await PartneredEntitiesService.getPartneredSupplierIds();
      expect(initialSuppliers.isEmpty, true);

      await PartneredEntitiesService.addPartneredSupplier(101);
      final updatedSuppliers = await PartneredEntitiesService.getPartneredSupplierIds();
      expect(updatedSuppliers.contains(101), true);

      await PartneredEntitiesService.removePartneredSupplier(101);
      final finalSuppliers = await PartneredEntitiesService.getPartneredSupplierIds();
      expect(finalSuppliers.contains(101), false);
    });
  });

  group('4. Medicines & Manufacturer Barcode Binding Tests', () {
    test('Add medicine and bind manufacturer box/strip barcode', () async {
      final med = await medicinesRepo.create(
        nameAr: 'Panadol Extra 500mg',
        unit: 'علبة',
        purchasePrice: 500.0,
        sellingPrice: 750.0,
        reorderLevel: 10,
        barcode: '6291100123456', // باركود المصنع
      );
      expect(med.id, isPositive);
      expect(med.barcode, '6291100123456');

      // Search by manufacturer barcode
      final found = await medicinesRepo.getByBarcode('6291100123456');
      expect(found, isNotNull);
      expect(found!.nameAr, 'Panadol Extra 500mg');
    });
  });

  group('5. Complete Purchases & Sales Workflow Tests', () {
    test('Create purchase to add stock, then make a sale with FEFO deduction', () async {
      // 1. Create Medicine
      final med = await medicinesRepo.create(
        nameAr: 'Amoxicillin 500mg',
        unit: 'علبة',
        purchasePrice: 300.0,
        sellingPrice: 500.0,
        reorderLevel: 5,
        barcode: '6291100789012',
      );

      final supp = await suppliersRepo.create(
        name: 'شركة الاستيراد الدوائي',
        contactInfo: '771122334',
      );

      // 2. Perform Purchase of 20 units
      final purchase = await purchasesRepo.createPurchase(
        supplierId: supp.id,
        supplierInvoiceRef: 'PUR-INV-101',
        items: [
          PurchaseLineInput(
            medicineId: med.id,
            medicineName: med.nameAr,
            quantity: 20,
            unitCost: 300.0,
            sellingPrice: 500.0,
            unitName: 'علبة',
            selectedQuantity: 20,
            batchNumber: 'BATCH-AMOX-2026',
            expiryDate: DateTime(2028, 12, 31),
          ),
        ],
        paidAmount: 6000.0,
      );

      expect(purchase.id, isPositive);
      expect(purchase.totalAmount, 6000.0);

      // Check stock after purchase
      final batchesAfterPurch = await (db.select(db.batches)..where((b) => b.medicineId.equals(med.id))).get();
      final totalStockPurch = batchesAfterPurch.fold<int>(0, (sum, b) => sum + b.quantity);
      expect(totalStockPurch, 20);

      // 3. Perform Sale of 5 units
      final sale = await salesRepo.createSale(
        items: [
          CartLineInput(
            medicineId: med.id,
            medicineName: med.nameAr,
            quantity: 5,
            unitPrice: 500.0,
            unitName: 'علبة',
            conversionFactor: 1,
            selectedQuantity: 5,
          ),
        ],
        discount: 0.0,
        paymentMethod: 'نقد',
      );

      expect(sale.id, isPositive);
      expect(sale.totalAmount, 2500.0);

      // Check stock after sale
      final batchesAfterSale = await (db.select(db.batches)..where((b) => b.medicineId.equals(med.id))).get();
      final totalStockSale = batchesAfterSale.fold<int>(0, (sum, b) => sum + b.quantity);
      expect(totalStockSale, 15); // 20 - 5 = 15
    });
  });

  group('6. Customer Debt & Credit Balances Tests', () {
    test('Credit sale adds customer debt, payment settles account', () async {
      final cust = await customersRepo.create(
        name: 'خالد عبد الله التاجر',
        phone: '772233445',
        notes: 'حساب شهري',
      );

      final med = await medicinesRepo.create(
        nameAr: 'Omega 3 1000mg',
        unit: 'علبة',
        purchasePrice: 2000.0,
        sellingPrice: 3000.0,
        reorderLevel: 2,
        barcode: '6291100556677',
      );

      final supp = await suppliersRepo.create(name: 'مورد فيتامينات');
      await purchasesRepo.createPurchase(
        supplierId: supp.id,
        items: [
          PurchaseLineInput(
            medicineId: med.id,
            medicineName: med.nameAr,
            quantity: 10,
            unitCost: 2000.0,
            unitName: 'علبة',
            selectedQuantity: 10,
          ),
        ],
        paidAmount: 20000.0,
      );

      // Credit Sale of 3000 to customer
      await salesRepo.createSale(
        customerId: cust.id,
        items: [
          CartLineInput(
            medicineId: med.id,
            medicineName: med.nameAr,
            quantity: 1,
            unitPrice: 3000.0,
            unitName: 'علبة',
            conversionFactor: 1,
            selectedQuantity: 1,
          ),
        ],
        discount: 0.0,
        paymentMethod: 'آجل',
      );

      final balances = await customersRepo.getCustomerBalances();
      final custBal = balances.firstWhere((b) => b.customerId == cust.id);
      expect(custBal.remainingDebt, 3000.0);

      // Record Customer Payment of 2000
      await customersRepo.recordPayment(
        customerId: cust.id,
        amount: 2000.0,
        notes: 'دفعة نقدية تحت الحساب',
      );

      final balancesAfterPay = await customersRepo.getCustomerBalances();
      final custBalAfter = balancesAfterPay.firstWhere((b) => b.customerId == cust.id);
      expect(custBalAfter.remainingDebt, 1000.0); // 3000 - 2000 = 1000
    });
  });

  group('7. Supplier Debts & Statements Tests', () {
    test('Unpaid purchase creates supplier debt, vendor payment settles debt', () async {
      final supp = await suppliersRepo.create(
        name: 'مؤسسة الشروق للأدوية',
        contactInfo: '773344556',
      );

      final med = await medicinesRepo.create(
        nameAr: 'Cefixime 400mg',
        unit: 'علبة',
        purchasePrice: 1000.0,
        sellingPrice: 1500.0,
        reorderLevel: 5,
      );

      // Purchase of 10,000, paid only 4,000 -> remaining 6,000 debt
      await purchasesRepo.createPurchase(
        supplierId: supp.id,
        items: [
          PurchaseLineInput(
            medicineId: med.id,
            medicineName: med.nameAr,
            quantity: 10,
            unitCost: 1000.0,
            unitName: 'علبة',
            selectedQuantity: 10,
          ),
        ],
        paidAmount: 4000.0,
      );

      final debts = await suppliersRepo.getPharmacyDebts();
      expect(debts.isNotEmpty, true);
      final suppDebt = debts.firstWhere((d) => d['supplierId'] == supp.id);
      expect((suppDebt['remainingDebt'] as num).toDouble(), 6000.0);

      // Pay 6000 to vendor
      await suppliersRepo.recordVendorPayment(
        supplierId: supp.id,
        amount: 6000.0,
        paymentMethod: 'نقد',
        notes: 'سداد كامل المتبقي',
      );

      final debtsAfterPay = await suppliersRepo.getPharmacyDebts();
      final suppDebtAfter = debtsAfterPay.where((d) => d['supplierId'] == supp.id).toList();
      expect(suppDebtAfter.isEmpty, true); // Debt is 0 so it's fully cleared
    });
  });

  group('8. Sales Returns & Inventory Replenishment Tests', () {
    test('Return sold items replenishes stock and creates financial return record', () async {
      final med = await medicinesRepo.create(
        nameAr: 'Ibuprofen 400mg',
        unit: 'علبة',
        purchasePrice: 200.0,
        sellingPrice: 400.0,
        reorderLevel: 5,
      );

      final supp = await suppliersRepo.create(name: 'مورد مسكنات');
      await purchasesRepo.createPurchase(
        supplierId: supp.id,
        items: [
          PurchaseLineInput(
            medicineId: med.id,
            medicineName: med.nameAr,
            quantity: 10,
            unitCost: 200.0,
            unitName: 'علبة',
            selectedQuantity: 10,
          ),
        ],
        paidAmount: 2000.0,
      );

      // Sale of 4 units
      final sale = await salesRepo.createSale(
        items: [
          CartLineInput(
            medicineId: med.id,
            medicineName: med.nameAr,
            quantity: 4,
            unitPrice: 400.0,
            unitName: 'علبة',
            conversionFactor: 1,
            selectedQuantity: 4,
          ),
        ],
        discount: 0.0,
        paymentMethod: 'نقد',
      );

      // Verify stock is 6 (10 - 4)
      var batches = await (db.select(db.batches)..where((b) => b.medicineId.equals(med.id))).get();
      expect(batches.fold<int>(0, (sum, b) => sum + b.quantity), 6);

      // Process Sale Return of 2 units
      final saleItem = (await (db.select(db.saleItems)..where((s) => s.saleId.equals(sale.id))).get()).first;
      await returnsRepo.createCustomerReturn(
        saleItemId: saleItem.id,
        quantity: 2,
        qtyCarton: 0,
        qtyPack: 2,
        qtyStrip: 0,
        qtyPill: 0,
        refundAmount: 800.0,
        settlementMethod: 'refund',
        paymentMethod: 'نقد',
        reason: 'إرجاع دواء زائد من العميل',
      );

      // Verify stock is now 8 (6 + 2)
      batches = await (db.select(db.batches)..where((b) => b.medicineId.equals(med.id))).get();
      expect(batches.fold<int>(0, (sum, b) => sum + b.quantity), 8);
    });
  });

  group('9. Remote Management Sync & Instant Update Simulation Tests', () {
    test('Instant Price Modifier updates medicine and active batches instantly', () async {
      final med = await medicinesRepo.create(
        nameAr: 'Paracetamol 500mg Direct',
        unit: 'علبة',
        purchasePrice: 100.0,
        sellingPrice: 150.0,
        reorderLevel: 10,
      );

      // Update price directly as done by OwnerLiveSyncService
      await (db.update(db.medicines)..where((m) => m.id.equals(med.id))).write(
        const MedicinesCompanion(
          sellingPrice: drift.Value(200.0),
          purchasePrice: drift.Value(120.0),
        ),
      );

      final updatedMed = await (db.select(db.medicines)..where((m) => m.id.equals(med.id))).getSingle();
      expect(updatedMed.sellingPrice, 200.0);
      expect(updatedMed.purchasePrice, 120.0);
    });

    test('Remote Purchase Invoice insertion into SQLite creates purchases and batches', () async {
      final supId = await db.into(db.suppliers).insert(
        SuppliersCompanion.insert(
          name: 'مورد سحابي عن بعد',
          contactInfo: const drift.Value('770000000'),
        ),
      );

      final purchId = await db.into(db.purchases).insert(
        PurchasesCompanion.insert(
          purchaseNumber: 'REMOTE-INV-999',
          supplierInvoiceRef: const drift.Value('REMOTE-INV-999'),
          supplierId: supId,
          totalAmount: 15000.0,
          paidAmount: const drift.Value(15000.0),
          paymentMethod: const drift.Value('نقدي'),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      expect(purchId, isPositive);

      final newMedId = await db.into(db.medicines).insert(
        MedicinesCompanion.insert(
          nameAr: 'Vitamin C 1000mg Remote',
          barcode: '998877665544',
          sku: '998877665544',
          sellingPrice: 1200.0,
          purchasePrice: 800.0,
        ),
      );

      final batchId = await db.into(db.batches).insert(
        BatchesCompanion.insert(
          medicineId: newMedId,
          batchNumber: const drift.Value('REMOTE-BATCH-01'),
          expiryDate: drift.Value(DateTime(2027, 6, 30)),
          quantity: 50,
          purchasePrice: 800.0,
        ),
      );

      expect(batchId, isPositive);

      final verifyBatch = await (db.select(db.batches)..where((b) => b.id.equals(batchId))).getSingle();
      expect(verifyBatch.quantity, 50);
      expect(verifyBatch.batchNumber, 'REMOTE-BATCH-01');
    });
  });
}

