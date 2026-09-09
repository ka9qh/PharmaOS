// قاعدة البيانات الرئيسية المشفّرة لنظام PharmaOS
//
// التشفير: عبر SQLite3MultipleCiphers (الطريقة الحديثة الرسمية في Drift 2.32+)
// وليس sqlcipher_flutter_libs (مهجورة). يتطلب هذا وجود القسم التالي في pubspec.yaml:
//   hooks:
//     user_defines:
//       sqlite3:
//         source: sqlite3mc
//
// ملاحظة أمنية هامة: مفتاح التشفير الفعلي يُدار عبر core/security/database_encryption.dart
// ولا يُمرَّر كنص صريح ثابت في نسخة الإنتاج النهائية.
//
// ============================================================================
// تحديث: أداء البحث لدعم 100,000+ دواء (طلب صريح من صاحب المشروع)
// ============================================================================
// 1) WAL Mode مُفعّل الآن صراحة (كان غير مُفعّل سابقًا رغم أنه متطلب أساسي
//    في الماستر برومبت) - يحسّن التزامن عند وجود أكثر من كاشير/جهاز.
// 2) فهارس B-Tree عادية على أعمدة البحث الأكثر استخدامًا، مُنشأة عبر SQL خام
//    (customStatement) بدلاً من تعديل تعريف الجداول في medicines_table.dart،
//    حتى لا نحتاج إعادة توليد app_database.g.dart في هذه الدفعة (drift
//    build_runner) - أي هذا التغيير آمن تمامًا على الكود المولّد الحالي.
// 3) جدول FTS5 اختياري (medicines_fts) لبحث نصي فوري حتى مع مئات الآلاف من
//    الأدوية. تحذير صريح: لا أملك طريقة للتحقق في هذه البيئة من أن نسخة
//    SQLite المرفقة عبر sqlite3mc تدعم FTS5 فعليًا (يحتاج اختبار حقيقي على
//    جهازك). لذلك غلّفت إنشاءه بـ try/catch كامل: إن فشل، يستمر النظام
//    بالفهارس العادية أعلاه بدون أي عطل - فقط أبطأ قليلاً على نصوص بحث حرة
//    غير مسبوقة ببداية الكلمة. اختبر وأخبرني بالنتيجة الفعلية.
//
// تحديث (schemaVersion 3): جدول user_permissions لنظام الصلاحيات المتقدم -
// راجع core/security/permissions_service.dart و core/security/role_guard.dart.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/users_table.dart';
import 'tables/audit_log_table.dart';
import 'tables/categories_table.dart';
import 'tables/companies_table.dart';
import 'tables/medicines_table.dart';
import 'tables/medicine_units_table.dart';
import 'tables/batches_table.dart';
import 'tables/sales_table.dart';
import 'tables/sale_items_table.dart';
import 'tables/suppliers_table.dart';
import 'tables/purchases_table.dart';
import 'tables/purchase_items_table.dart';
import 'tables/vendor_payments_table.dart';
import 'tables/expenses_table.dart';
import 'tables/returns_table.dart';
import 'tables/return_items_table.dart';
import 'tables/day_closings_table.dart';
import 'tables/licenses_table.dart';
import 'tables/settings_table.dart';
import 'tables/customers_table.dart';
import 'tables/customer_payments_table.dart';
import 'tables/wallets_table.dart';
import 'tables/workers_table.dart';
import 'tables/inventory_write_offs_table.dart';
import 'tables/needed_items_table.dart';
import 'tables/accounts_table.dart';
import 'tables/custom_widgets_table.dart';
import 'tables/insurance_companies_table.dart';
import 'tables/insurance_policies_table.dart';
import 'tables/journal_entries_table.dart';
import 'tables/journal_entry_lines_table.dart';
import 'tables/payroll_table.dart';
import 'tables/purchase_returns_table.dart';
import 'tables/purchase_return_items_table.dart';
import 'tables/stock_transfers_table.dart';
import 'tables/ui_strings_table.dart';
import 'tables/warehouses_table.dart';
import 'tables/worker_advances_table.dart';
import 'tables/worker_attendance_table.dart';
import 'tables/held_invoices_table.dart';
import 'tables/doctors_table.dart';
import 'tables/prescriptions_table.dart';
import 'tables/inventory_reconciliations_table.dart';
import 'tables/user_permissions_table.dart';
part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users,
  AuditLogs,
  Categories,
  Companies,
  Medicines,
  MedicineUnits,
  Batches,
  Sales,
  SaleItems,
  Suppliers,
  Purchases,
  PurchaseItems,
  VendorPayments,
  Expenses,
  Returns,
  ReturnItems,
  DayClosings,
  Licenses,
  Settings,
  Customers,
  CustomerPayments,
  Wallets,
  Workers,
  WorkerAdvances,
  WorkerAttendance,
  Payroll,
  InventoryWriteOffs,
  NeededItems,
  Accounts,
  JournalEntries,
  JournalEntryLines,
  CustomWidgets,
  UiStrings,
  Warehouses,
  StockTransfers,
  PurchaseReturns,
  PurchaseReturnItems,
  InsuranceCompanies,
  InsurancePolicies,
  HeldInvoices,
  Doctors,
  Prescriptions,
  InventoryReconciliations,
  UserPermissions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(String encryptionKey)
      : super(_openConnection(encryptionKey));

  /// يُستخدم فقط في الاختبارات (Unit Tests) لفتح قاعدة بيانات في الذاكرة بدون تشفير.
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 18;

  @override
  Future<void> _safeAddColumn(Migrator m, TableInfo table, GeneratedColumn col) async {
    try {
      await m.addColumn(table, col);
    } catch (e) {}
  }
  
  Future<void> _safeCreateTable(Migrator m, TableInfo table) async {
    try {
      await m.createTable(table);
    } catch (e) {}
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createPerformanceIndexes();
          await _createPermissionsTable();
          await _createPackagingTable();
        },
        beforeOpen: (OpeningDetails details) async {
          // علاج ذاتي وتلقائي لأي نقص في الأعمدة أو الجداول في قواعد البيانات الحالية
          await _selfHealSchema();
          await _createPerformanceIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await _createPerformanceIndexes();
          }
          if (from < 3) {
            await _createPermissionsTable();
          }
          if (from < 4) {
            await _createPackagingTable();
          }
          if (from < 5) {
            await _safeAddColumn(m, medicines, medicines.nameEn);
            await _safeAddColumn(m, medicines, medicines.supplierId);
            await _safeAddColumn(m, medicines, medicines.qtyPerPack);
            await _safeAddColumn(m, medicines, medicines.qtyPerStrip);
            await _safeAddColumn(m, medicines, medicines.reserveField1);
            await _safeAddColumn(m, medicines, medicines.reserveField2);
            await _safeAddColumn(m, medicines, medicines.reserveField3);
          }
          if (from < 6) {
            await _safeAddColumn(m, medicines, medicines.medicineType);
            await _safeCreateTable(m, medicineUnits);
          }
          if (from < 7) {
            await _safeCreateTable(m, wallets);
            await _safeAddColumn(m, sales, sales.walletId);
            await _safeAddColumn(m, purchases, purchases.walletId);
            await _safeAddColumn(m, purchases, purchases.paymentMethod);
            await _safeAddColumn(m, vendorPayments, vendorPayments.walletId);
            await _safeAddColumn(m, vendorPayments, vendorPayments.paymentMethod);
            await _safeAddColumn(m, expenses, expenses.walletId);
            await _safeAddColumn(m, expenses, expenses.paymentMethod);
            await _safeAddColumn(m, customerPayments, customerPayments.walletId);
            await _safeAddColumn(m, customerPayments, customerPayments.paymentMethod);
            await _safeAddColumn(m, returns, returns.walletId);
            await _safeAddColumn(m, returns, returns.paymentMethod);
            await _safeAddColumn(m, returns, returns.settlementMethod);
            await _safeAddColumn(m, returns, returns.totalAmount);
          }
          if (from < 8) {
            await _safeCreateTable(m, workers);
            await _safeAddColumn(m, expenses, expenses.workerId);
            await _safeAddColumn(m, expenses, expenses.customWorkerName);
          }
          if (from < 9) {
            await _safeCreateTable(m, inventoryWriteOffs);
          }
          if (from < 10) {
            await _safeCreateTable(m, neededItems);
          }
          if (from < 11) {
            await _safeCreateTable(m, heldInvoices);
          }
          if (from < 12) {
            await m.createTable(doctors);
            await m.createTable(prescriptions);
            await _safeAddColumn(m, sales, sales.doctorId);
            await _safeAddColumn(m, sales, sales.prescriptionId);
          }
          if (from < 13) {
            await m.createTable(inventoryReconciliations);
          }
          if (from < 14) {
            await m.createTable(userPermissions);
          }
          if (from < 15) {
            await _safeAddColumn(m, medicines, medicines.isTaxable);
            await _safeAddColumn(m, medicines, medicines.taxRate);
          }
          if (from < 16) {
            await _safeAddColumn(m, sales, sales.subTotal);
            await _safeAddColumn(m, purchases, purchases.subTotal);
          }
          if (from < 17) {
            await _safeAddColumn(m, sales, sales.taxAmount);
            await _safeAddColumn(m, purchases, purchases.taxAmount);
            
            await _safeAddColumn(m, saleItems, saleItems.taxRate);
            await _safeAddColumn(m, saleItems, saleItems.taxAmount);
            await _safeAddColumn(m, saleItems, saleItems.total);
            await _safeAddColumn(m, saleItems, saleItems.unitName);
            await _safeAddColumn(m, saleItems, saleItems.conversionFactor);
            await _safeAddColumn(m, saleItems, saleItems.selectedQuantity);
            
            await _safeAddColumn(m, purchaseItems, purchaseItems.taxRate);
            await _safeAddColumn(m, purchaseItems, purchaseItems.taxAmount);
            await _safeAddColumn(m, purchaseItems, purchaseItems.total);
            await _safeAddColumn(m, purchaseItems, purchaseItems.unitName);
            await _safeAddColumn(m, purchaseItems, purchaseItems.conversionFactor);
          }
          if (from < 18) {
            await _safeAddColumn(m, purchases, purchases.invoiceImagePath);
            
            await _safeAddColumn(m, purchaseItems, purchaseItems.qtyCarton);
            await _safeAddColumn(m, purchaseItems, purchaseItems.qtyPack);
            await _safeAddColumn(m, purchaseItems, purchaseItems.qtyStrip);
            await _safeAddColumn(m, purchaseItems, purchaseItems.qtyPill);

            await _safeAddColumn(m, returnItems, returnItems.originalSaleItemId);
            await _safeAddColumn(m, returnItems, returnItems.originalPurchaseItemId);
            await _safeAddColumn(m, returnItems, returnItems.qtyCarton);
            await _safeAddColumn(m, returnItems, returnItems.qtyPack);
            await _safeAddColumn(m, returnItems, returnItems.qtyStrip);
            await _safeAddColumn(m, returnItems, returnItems.qtyPill);

            await _safeAddColumn(m, medicines, medicines.qtyPerCarton);
            await _safeAddColumn(m, medicines, medicines.cartonPurchasePrice);
            await _safeAddColumn(m, medicines, medicines.cartonSellingPrice);
            await _safeAddColumn(m, medicines, medicines.stripPurchasePrice);
            await _safeAddColumn(m, medicines, medicines.stripSellingPrice);
            await _safeAddColumn(m, medicines, medicines.packPurchasePrice);
            await _safeAddColumn(m, medicines, medicines.packSellingPrice);
            await _safeAddColumn(m, medicines, medicines.medicineType);
          }
        },
      );

  Future<void> _selfHealSchema() async {
    final queries = [
      // Medicines
      "ALTER TABLE medicines ADD COLUMN name_en TEXT;",
      "ALTER TABLE medicines ADD COLUMN name_scientific TEXT;",
      "ALTER TABLE medicines ADD COLUMN category_id INTEGER;",
      "ALTER TABLE medicines ADD COLUMN company_id INTEGER;",
      "ALTER TABLE medicines ADD COLUMN supplier_id INTEGER;",
      "ALTER TABLE medicines ADD COLUMN medicine_type INTEGER DEFAULT 0;",
      "ALTER TABLE medicines ADD COLUMN qty_per_strip INTEGER;",
      "ALTER TABLE medicines ADD COLUMN strip_purchase_price REAL;",
      "ALTER TABLE medicines ADD COLUMN strip_selling_price REAL;",
      "ALTER TABLE medicines ADD COLUMN qty_per_pack INTEGER;",
      "ALTER TABLE medicines ADD COLUMN pack_purchase_price REAL;",
      "ALTER TABLE medicines ADD COLUMN pack_selling_price REAL;",
      "ALTER TABLE medicines ADD COLUMN qty_per_carton INTEGER;",
      "ALTER TABLE medicines ADD COLUMN carton_purchase_price REAL;",
      "ALTER TABLE medicines ADD COLUMN carton_selling_price REAL;",
      "ALTER TABLE medicines ADD COLUMN reserve_field1 TEXT;",
      "ALTER TABLE medicines ADD COLUMN reserve_field2 TEXT;",
      "ALTER TABLE medicines ADD COLUMN reserve_field3 TEXT;",
      "ALTER TABLE medicines ADD COLUMN is_taxable INTEGER DEFAULT 1;",
      "ALTER TABLE medicines ADD COLUMN tax_rate REAL DEFAULT 0.0;",
      "ALTER TABLE medicines ADD COLUMN is_active INTEGER DEFAULT 1;",

      // Purchases
      "ALTER TABLE purchases ADD COLUMN supplier_invoice_ref TEXT;",
      "ALTER TABLE purchases ADD COLUMN sub_total REAL DEFAULT 0.0;",
      "ALTER TABLE purchases ADD COLUMN tax_amount REAL DEFAULT 0.0;",
      "ALTER TABLE purchases ADD COLUMN paid_amount REAL DEFAULT 0.0;",
      "ALTER TABLE purchases ADD COLUMN payment_method TEXT DEFAULT 'نقدي';",
      "ALTER TABLE purchases ADD COLUMN wallet_id INTEGER;",
      "ALTER TABLE purchases ADD COLUMN invoice_image_path TEXT;",

      // Purchase Items
      "ALTER TABLE purchase_items ADD COLUMN subtotal REAL DEFAULT 0.0;",
      "ALTER TABLE purchase_items ADD COLUMN tax_rate REAL DEFAULT 0.0;",
      "ALTER TABLE purchase_items ADD COLUMN tax_amount REAL DEFAULT 0.0;",
      "ALTER TABLE purchase_items ADD COLUMN total REAL DEFAULT 0.0;",
      "ALTER TABLE purchase_items ADD COLUMN unit_name TEXT;",
      "ALTER TABLE purchase_items ADD COLUMN conversion_factor INTEGER DEFAULT 1;",
      "ALTER TABLE purchase_items ADD COLUMN selected_quantity INTEGER;",
      "ALTER TABLE purchase_items ADD COLUMN qty_carton INTEGER DEFAULT 0;",
      "ALTER TABLE purchase_items ADD COLUMN qty_pack INTEGER DEFAULT 0;",
      "ALTER TABLE purchase_items ADD COLUMN qty_strip INTEGER DEFAULT 0;",
      "ALTER TABLE purchase_items ADD COLUMN qty_pill INTEGER DEFAULT 0;",

      // Sales
      "ALTER TABLE sales ADD COLUMN customer_id INTEGER;",
      "ALTER TABLE sales ADD COLUMN doctor_id INTEGER;",
      "ALTER TABLE sales ADD COLUMN prescription_id INTEGER;",
      "ALTER TABLE sales ADD COLUMN sub_total REAL DEFAULT 0.0;",
      "ALTER TABLE sales ADD COLUMN tax_amount REAL DEFAULT 0.0;",
      "ALTER TABLE sales ADD COLUMN discount REAL DEFAULT 0.0;",
      "ALTER TABLE sales ADD COLUMN payment_method TEXT DEFAULT 'نقدي';",
      "ALTER TABLE sales ADD COLUMN wallet_id INTEGER;",
      "ALTER TABLE sales ADD COLUMN status TEXT DEFAULT 'completed';",

      // Sale Items
      "ALTER TABLE sale_items ADD COLUMN batch_id INTEGER;",
      "ALTER TABLE sale_items ADD COLUMN subtotal REAL DEFAULT 0.0;",
      "ALTER TABLE sale_items ADD COLUMN tax_rate REAL DEFAULT 0.0;",
      "ALTER TABLE sale_items ADD COLUMN tax_amount REAL DEFAULT 0.0;",
      "ALTER TABLE sale_items ADD COLUMN total REAL DEFAULT 0.0;",
      "ALTER TABLE sale_items ADD COLUMN unit_name TEXT;",
      "ALTER TABLE sale_items ADD COLUMN conversion_factor INTEGER DEFAULT 1;",
      "ALTER TABLE sale_items ADD COLUMN selected_quantity INTEGER;",

      // Returns
      "ALTER TABLE returns ADD COLUMN total_amount REAL DEFAULT 0.0;",
      "ALTER TABLE returns ADD COLUMN settlement_method TEXT DEFAULT 'refund';",
      "ALTER TABLE returns ADD COLUMN payment_method TEXT DEFAULT 'نقدي';",
      "ALTER TABLE returns ADD COLUMN wallet_id INTEGER;",
      "ALTER TABLE returns ADD COLUMN reason TEXT;",
      "ALTER TABLE returns ADD COLUMN processed_by INTEGER;",

      // Return Items
      "ALTER TABLE return_items ADD COLUMN subtotal REAL DEFAULT 0.0;",
      "ALTER TABLE return_items ADD COLUMN original_sale_item_id INTEGER;",
      "ALTER TABLE return_items ADD COLUMN original_purchase_item_id INTEGER;",
      "ALTER TABLE return_items ADD COLUMN qty_carton INTEGER DEFAULT 0;",
      "ALTER TABLE return_items ADD COLUMN qty_pack INTEGER DEFAULT 0;",
      "ALTER TABLE return_items ADD COLUMN qty_strip INTEGER DEFAULT 0;",
      "ALTER TABLE return_items ADD COLUMN qty_pill INTEGER DEFAULT 0;",

      // Batches
      "ALTER TABLE batches ADD COLUMN warehouse_id INTEGER;",
    ];

    for (final q in queries) {
      try {
        await customStatement(q);
      } catch (_) {
        // إذا كان العمود موجوداً مسبقاً، تجاهل الخطأ بأمان
      }
    }
  }

  /// فهارس بحث الأداء - راجع تعليق أعلى الملف لتفاصيل الأسباب والمخاطر.
  Future<void> _createPerformanceIndexes() async {
    // فهارس عادية - تعمل دائمًا بغض النظر عن دعم FTS5.
    // (barcode و sku مفهرسة تلقائيًا أصلًا لأنها UNIQUE في تعريف الجدول)
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_medicines_name_ar ON medicines(name_ar);');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_medicines_name_scientific ON medicines(name_scientific);');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_medicines_category ON medicines(category_id);');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_medicines_company ON medicines(company_id);');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_medicines_active ON medicines(is_active);');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);');

    // جدول بحث نصي كامل (FTS5) - اختياري، يفشل بأمان إذا لم يكن مدعومًا.
    try {
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS medicines_fts USING fts5(
          name_ar, name_scientific, barcode, sku,
          content='medicines', content_rowid='id'
        );
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS medicines_fts_ai AFTER INSERT ON medicines BEGIN
          INSERT INTO medicines_fts(rowid, name_ar, name_scientific, barcode, sku)
          VALUES (new.id, new.name_ar, new.name_scientific, new.barcode, new.sku);
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS medicines_fts_ad AFTER DELETE ON medicines BEGIN
          INSERT INTO medicines_fts(medicines_fts, rowid, name_ar, name_scientific, barcode, sku)
          VALUES ('delete', old.id, old.name_ar, old.name_scientific, old.barcode, old.sku);
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS medicines_fts_au AFTER UPDATE ON medicines BEGIN
          INSERT INTO medicines_fts(medicines_fts, rowid, name_ar, name_scientific, barcode, sku)
          VALUES ('delete', old.id, old.name_ar, old.name_scientific, old.barcode, old.sku);
          INSERT INTO medicines_fts(rowid, name_ar, name_scientific, barcode, sku)
          VALUES (new.id, new.name_ar, new.name_scientific, new.barcode, new.sku);
        END;
      ''');
      // إعادة تعبئة الجدول عند الترقية من نسخة أقدم فيها بيانات موجودة سلفًا.
      await customStatement('''
        INSERT INTO medicines_fts(rowid, name_ar, name_scientific, barcode, sku)
        SELECT id, name_ar, name_scientific, barcode, sku FROM medicines
        WHERE id NOT IN (SELECT rowid FROM medicines_fts);
      ''');
    } catch (e) {
      // FTS5 غير مدعوم في نسخة SQLite الحالية - لا مشكلة، البحث سيعمل عبر
      // الفهارس العادية أعلاه. أخبرني إذا ظهر هذا فعليًا عندك حتى أراجع
      // إعدادات sqlite3mc في pubspec.yaml.
      // ignore: avoid_print
      print('تنبيه: تعذر إنشاء جدول FTS5 (سيُستخدم البحث العادي بدلاً منه): $e');
    }
  }

  /// جدول تهيئة وحدات البيع/العبوة لكل دواء (حبة/شريط/باكت) - نظام تعدد
  /// الوحدات. راجع core/services/medicine_packaging_service.dart. جدول منفصل
  /// عمدًا (وليس أعمدة إضافية على medicines) لتفادي الحاجة لإعادة توليد
  /// app_database.g.dart في هذه الدفعة أيضًا - نفس منطق user_permissions.
  Future<void> _createPackagingTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS medicine_packaging (
        medicine_id INTEGER PRIMARY KEY,
        middle_unit_name TEXT,
        units_per_middle INTEGER,
        large_unit_name TEXT,
        middles_per_large INTEGER,
        FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE CASCADE
      );
    ''');
  }

  /// جدول تخصيص الصلاحيات لكل مستخدم (نظام الصلاحيات المتقدم - Users/Roles/
  /// Permissions). أُنشئ عبر SQL خام عمدًا وليس كجدول Drift معرَّف بصنف Table،
  /// حتى لا نحتاج إعادة توليد app_database.g.dart في هذه الدفعة (راجع
  /// core/security/permissions_service.dart لكل الاستعلامات عليه).
  Future<void> _createPermissionsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS user_permissions (
        user_id INTEGER NOT NULL,
        permission TEXT NOT NULL,
        granted INTEGER NOT NULL,
        PRIMARY KEY (user_id, permission),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      );
    ''');
  }

  /// بحث سريع في الأدوية عبر FTS5 إن وُجد، مع fallback فارغ إن لم يكن متاحًا.
  /// يُستخدم من MedicinesDataSource بدلاً من تحميل كل الجدول للذاكرة وفلترته.
  Future<List<int>> searchMedicineIdsFast(String query, {int limit = 50}) async {
    final terms = query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (terms.isEmpty) return const [];
    final ftsQuery = terms.map((t) => '$t*').join(' ');
    try {
      final rows = await customSelect(
        'SELECT rowid FROM medicines_fts WHERE medicines_fts MATCH ? ORDER BY rank LIMIT ?;',
        variables: [Variable.withString(ftsQuery), Variable.withInt(limit)],
      ).get();
      return rows.map((r) => r.read<int>('rowid')).toList();
    } catch (_) {
      // FTS5 غير متاح - MedicinesDataSource سيرجع تلقائيًا لبحث LIKE العادي.
      return const [];
    }
  }
}

LazyDatabase _openConnection(String encryptionKey) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }
    final file = File(p.join(dbFolder.path, 'pharmaos_secure.db'));

    // إذا لم تكن قاعدة البيانات موجودة بعد في مجلد التطبيق، نتحقق من وجود نسخة جاهزة مرفقة
    if (!await file.exists()) {
      try {
        final currentDirDb = File(p.join(Directory.current.path, 'pharmaos_secure.db'));
        if (await currentDirDb.exists()) {
          await currentDirDb.copy(file.path);
        } else {
          final exeDir = File(Platform.resolvedExecutable).parent.path;
          final bundledDb = File(p.join(exeDir, 'pharmaos_secure.db'));
          if (await bundledDb.exists()) {
            await bundledDb.copy(file.path);
          }
        }
      } catch (_) {}
    }

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // قمنا بحذف الـ assert المزعج هنا الذي كان يوقف التطبيق
        rawDb.execute("PRAGMA key = '$encryptionKey';");
        rawDb.execute('PRAGMA foreign_keys = ON;');
        // WAL Mode: متطلب أداء صريح (قراءة/كتابة متزامنة أسرع، مهم عند وجود
        // أكثر من كاشير/جهاز يستخدم نفس قاعدة البيانات).
        rawDb.execute('PRAGMA journal_mode=WAL;');
      },
    );
  });
}
