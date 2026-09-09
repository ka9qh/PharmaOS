import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:pharmaos/core/database/app_database.dart';
import 'package:pharmaos/core/security/audit_logger.dart';
import 'package:pharmaos/core/security/permissions_service.dart';
import 'package:pharmaos/core/security/role_guard.dart';
import 'package:pharmaos/features/accounting/data/repositories/general_ledger_repository_impl.dart';
import 'package:pharmaos/features/purchases/data/datasources/purchases_datasource.dart';
import 'package:pharmaos/features/sales/data/datasources/sales_datasource.dart';
import 'package:pharmaos/features/sales/domain/entities/sales_entity.dart';
import 'package:pharmaos/features/inventory/data/datasources/inventory_datasource.dart';
import 'package:pharmaos/features/returns/data/datasources/returns_datasource.dart';
import 'package:drift/drift.dart';

void main() {
  test('Comprehensive System Audit & Test Protocol (In-Memory Database)', () async {
    print('\n======================================================');
    print('🚀 بدء تنفيذ دليل الاختبار والفحص الشامل للنظام');
    print('======================================================\n');

    // 1. تهيئة قاعدة البيانات المشفرة في الذاكرة
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final auditLogger = AuditLogger(db);
    final glRepo = GeneralLedgerRepositoryImpl(db);
    final permissionsService = PermissionsService(db, auditLogger);
    final purchasesDs = PurchasesDataSourceImpl(db, glRepo);
    final salesDs = SalesDataSourceImpl(db, glRepo);
    final inventoryDs = InventoryDataSourceImpl(db, glRepo);
    final returnsDs = ReturnsDataSourceImpl(db, glRepo);

    // زراعة الحسابات المحاسبية الأساسية المطلوبة للقيود
    await glRepo.seedDefaultAccountsIfEmpty();

    print('✓ [1/7] تم تهيئة محرك النظام، الحسابات المحاسبية، وقاعدة البيانات بنجاح.');

    // 2. إنشاء السجلات الأساسية (دواء، مورد، طبيب، وصفة طبية)
    final supplierId = await db.into(db.suppliers).insert(
      SuppliersCompanion.insert(
        name: 'شركة فارما العالمية للأدوية',
        contactInfo: Value('777123456'),
      ),
    );

    final medicineId = await db.into(db.medicines).insert(
      MedicinesCompanion.insert(
        nameAr: 'بنادول إكسترا أدفانس',
        nameEn: Value('Panadol Extra Advance'),
        nameScientific: Value('Paracetamol 500mg + Caffeine 65mg'),
        barcode: 'BAR-629104',
        sku: 'SKU-MED-001',
        purchasePrice: 1000.0,
        sellingPrice: 1500.0,
      ),
    );

    final doctorId = await db.into(db.doctors).insert(
      DoctorsCompanion.insert(
        name: 'د. وليد الصنعاني',
        specialty: Value('استشاري باطنية وقلب'),
        phone: Value('771122334'),
      ),
    );

    final prescriptionId = await db.into(db.prescriptions).insert(
      PrescriptionsCompanion.insert(
        doctorId: Value(doctorId),
        prescriptionNumber: Value('RX-2026-009'),
        diagnosis: Value('صداع نصفي حاد وإجهاد'),
      ),
    );

    print('✓ [2/7] تم إنشاء السجلات الأساسية (دواء، مورد، طبيب، وصفة طبية).');

    // 3. فحص المشتريات وتعدد الدفعات وتواريخ الصلاحية
    final expiryNear = DateTime.now().add(const Duration(days: 30)); // تنتهي بعد شهر
    final expiryFar = DateTime.now().add(const Duration(days: 365)); // تنتهي بعد سنة

    final purchaseResult = await purchasesDs.createPurchaseTransactional(
      supplierId: supplierId,
      supplierInvoiceRef: 'INV-SUP-9988',
      paidAmount: 30000.0,
      items: [
        (
          medicineId: medicineId,
          quantity: 10,
          unitCost: 1000.0,
          batchNumber: 'BATCH-NEAR-2026',
          expiryDate: expiryNear,
        ),
        (
          medicineId: medicineId,
          quantity: 20,
          unitCost: 1000.0,
          batchNumber: 'BATCH-FAR-2027',
          expiryDate: expiryFar,
        ),
      ],
    );

    expect(purchaseResult.id, isPositive);
    final stockAfterPurchase = await inventoryDs.getAvailableQuantity(medicineId);
    expect(stockAfterPurchase, equals(30));
    print('✓ [3/7] فحص المشتريات والمخزن: تم شراء 30 حبة على دفعتين (10 قريبة، 20 بعيدة)، الرصيد بالمخزن = $stockAfterPurchase حبة.');

    // 4. فحص خوارزمية البيع وصرف FEFO بصرامة وربط الطبيب والوصفة
    final saleInvoice = await salesDs.createSaleTransactional(
      items: [
        CartLineInput(
          medicineId: medicineId,
          medicineName: 'بنادول إكسترا أدفانس',
          quantity: 15, // يسحب 10 من الدفعة القريبة و 5 من الدفعة البعيدة
          unitPrice: 1500.0,
          unitName: 'باكت',
          conversionFactor: 1,
          selectedQuantity: 15,
        ),
      ],
      discount: 0.0,
      paymentMethod: 'نقدي',
      doctorId: doctorId,
      prescriptionId: prescriptionId,
    );

    expect(saleInvoice.id, isPositive);

    // التحقق من حالة الدفعات بعد البيع
    final batches = await (db.select(db.batches)..where((b) => b.medicineId.equals(medicineId))).get();
    final batchNear = batches.firstWhere((b) => b.batchNumber == 'BATCH-NEAR-2026');
    final batchFar = batches.firstWhere((b) => b.batchNumber == 'BATCH-FAR-2027');

    expect(batchNear.quantity, equals(0)); // نفدت تماماً
    expect(batchFar.quantity, equals(15)); // تبقى 15
    print('✓ [4/7] فحص خوارزمية FEFO: تم استهلاك الدفعة الأقرب انتهاءً بالكامل (10/10) واستهلاك (5) من الدفعة الأبعد. المتبقي: ${batchFar.quantity} حبة.');

    // 5. فحص منع الثغرات الأمنية (تعديل تاريخ الانتهاء لتاريخ غير متوفر)
    print('🔍 [5/7] فحص الأمان ومنع الثغرات: محاولة بيع دواء بتاريخ غير متوفر بالمخزون...');
    bool errorCaught = false;
    try {
      await salesDs.createSaleTransactional(
        items: [
          CartLineInput(
            medicineId: medicineId,
            medicineName: 'بنادول إكسترا أدفانس',
            quantity: 2,
            unitPrice: 1500.0,
            unitName: 'باكت',
            conversionFactor: 1,
            selectedQuantity: 2,
            expiryDate: DateTime(2035, 1, 1),
            batchId: 999999, // Batch ID غير موجود
          ),
        ],
        discount: 0.0,
        paymentMethod: 'نقدي',
      );
    } catch (e) {
      errorCaught = true;
      print('   🛡️ تم اعتراض وتأكيد الحماية: ${e.toString()}');
    }
    expect(errorCaught, isTrue);

    // التأكد من عدم وجود أي كميات سالبة
    final negativeBatches = await (db.select(db.batches)
      ..where((b) => b.medicineId.equals(medicineId) & b.quantity.isSmallerThanValue(0))).get();
    expect(negativeBatches.isEmpty, isTrue);
    print('✓ [5/7] اجتياز فحص الثغرات: تم رفض البيع بتواريخ غير متوفرة، وتأكيد عدم وجود أي أرصدة سالبة.');

    // 6. فحص المرتجعات والتسوية الجردية
    final saleItems = await (db.select(db.saleItems)..where((s) => s.saleId.equals(saleInvoice.id))).get();
    expect(saleItems.isNotEmpty, isTrue);
    final itemToReturn = saleItems.first;

    await returnsDs.createCustomerReturnTransactional(
      saleItemId: itemToReturn.id,
      quantity: 5,
      reason: 'فحص استرجاع العميل',
    );

    final stockAfterReturn = await inventoryDs.getAvailableQuantity(medicineId);
    expect(stockAfterReturn, equals(20)); // 15 + 5 = 20
    print('✓ [6/7] فحص المرتجعات: تم إرجاع 5 حبات بنجاح وعاد رصيد المخزن إلى $stockAfterReturn حبة.');

    // إجراء تسوية جردية (المخزن 20 دفترياً، والجرد الفعلي 18 حبة - عجز 2 حبة)
    await inventoryDs.reconcileStock(
      medicineId: medicineId,
      actualQuantity: 18,
      systemQuantity: 20,
      note: 'عجز جرد فحص شامل',
      userId: 1,
    );

    final stockAfterReconcile = await inventoryDs.getAvailableQuantity(medicineId);
    expect(stockAfterReconcile, equals(18));
    print('✓ [6/7] فحص التسوية الجردية: تم تسوية العجز (2 حبة) بنجاح وأصبح الرصيد الفعلي في النظام = $stockAfterReconcile حبة.');

    // 7. فحص نظام الصلاحيات المتقدمة (Users / Roles / Permissions)
    final testUser = await db.into(db.users).insertReturning(
      UsersCompanion.insert(
        fullName: 'كاشير تجريبي فحص',
        username: 'cashier_audit_user',
        passwordHash: 'hash',
        role: AppRole.cashier.name,
      ),
    );

    // الصلاحيات الافتراضية للكاشير
    final cashierDefaults = await permissionsService.effectivePermissionsFor(testUser.id, AppRole.cashier);
    expect(cashierDefaults.contains(AppPermission.usePos), isTrue);
    expect(cashierDefaults.contains(AppPermission.viewProfits), isFalse);
    expect(cashierDefaults.contains(AppPermission.deleteInvoice), isFalse);

    // منح صلاحية مخصصة استثنائية (مشاهدة الأرباح)
    await permissionsService.setOverride(
      userId: testUser.id,
      permission: AppPermission.viewProfits,
      granted: true,
      changedByUserId: 1,
    );

    final permsAfterOverride = await permissionsService.effectivePermissionsFor(testUser.id, AppRole.cashier);
    expect(permsAfterOverride.contains(AppPermission.viewProfits), isTrue);

    // سحب صلاحية افتراضية (استخدام نقطة البيع)
    await permissionsService.setOverride(
      userId: testUser.id,
      permission: AppPermission.usePos,
      granted: false,
      changedByUserId: 1,
    );

    final finalPerms = await permissionsService.effectivePermissionsFor(testUser.id, AppRole.cashier);
    expect(finalPerms.contains(AppPermission.usePos), isFalse);

    print('✓ [7/7] فحص الصلاحيات المتقدمة: تم اختبار الصلاحيات الافتراضية، ومنح صلاحيات مخصصة، وسحب صلاحيات افتراضية بنجاح تام.');

    print('\n======================================================');
    print('🎉 النتيجة النهائية: تم اجتياز كافة بنود دليل الفحص بنجاح 100%');
    print('======================================================\n');

    await db.close();
  });
}
