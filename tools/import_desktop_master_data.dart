import 'dart:io';
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final dbPath = '$appData\\com.example\\pharmaos\\pharmaos_secure.db';
  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    print('❌ قاعدة البيانات غير موجودة في: $dbPath');
    return;
  }

  print('🚀 فتح قاعدة البيانات: $dbPath');
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");
  db.execute('PRAGMA foreign_keys = OFF;');

  final basePath = 'C:\\Users\\hp\\Desktop\\اكسل الصيدليه\\الجداول_الموحدة_الشاملة';

  final catFile = File('$basePath\\Master_Categories_Complete.csv');
  final compFile = File('$basePath\\Master_Companies_Complete.csv');
  final suppFile = File('$basePath\\Master_Suppliers_Complete.csv');
  final medFile = File('$basePath\\Master_Medicines_Complete.csv');

  if (!catFile.existsSync() || !compFile.existsSync() || !suppFile.existsSync() || !medFile.existsSync()) {
    print('❌ أحد ملفات البيانات غير موجود في المسار: $basePath');
    return;
  }

  db.execute('BEGIN TRANSACTION;');

  try {
    // ==========================================
    // 1. تهيئة دليل الحسابات العامة (Chart of Accounts)
    // ==========================================
    print('\n📊 1. تهيئة دليل الحسابات العامة...');
    final existingAccounts = db.select('SELECT count(*) as c FROM accounts;').first['c'] as int;
    if (existingAccounts == 0) {
      final accountsData = [
        ['1', 'الأصول', 'Asset', null, 1, 1],
        ['11', 'الأصول المتداولة', 'Asset', 1, 1, 1],
        ['1101', 'صندوق النقدية الرئيسي', 'Asset', 2, 0, 1],
        ['1102', 'المخزون السلعي (الأدوية)', 'Asset', 2, 0, 1],
        ['1103', 'العملاء والذمم المدينة', 'Asset', 2, 0, 1],
        ['2', 'الخصوم والالتزامات', 'Liability', null, 1, 1],
        ['21', 'الخصوم المتداولة', 'Liability', 6, 1, 1],
        ['2101', 'الموردين والذمم الدائنة', 'Liability', 7, 0, 1],
        ['4', 'الإيرادات', 'Revenue', null, 1, 1],
        ['4101', 'إيرادات مبيعات الصيدلية', 'Revenue', 9, 0, 1],
        ['4102', 'مردودات ومسموحات المبيعات', 'Revenue', 9, 0, 1],
        ['5', 'المصروفات', 'Expense', null, 1, 1],
        ['5101', 'تكلفة البضاعة المباعة', 'Expense', 12, 0, 1],
        ['5201', 'المصروفات العمومية والتشغيلية', 'Expense', 12, 0, 1],
      ];

      final insertAccStmt = db.prepare('''
        INSERT OR IGNORE INTO accounts (code, name, type, parent_id, is_header, is_system_account, balance, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, 0.0, datetime('now'), datetime('now'));
      ''');

      for (final a in accountsData) {
        insertAccStmt.execute([a[0], a[1], a[2], a[3], a[4], a[5]]);
      }
      insertAccStmt.dispose();
      print('   ✓ تم إنشاء شجرة الحسابات المحاسبية بنجاح.');
    } else {
      print('   ✓ الحسابات موجودة مسبقاً ($existingAccounts حساب).');
    }

    // ==========================================
    // 2. استيراد التصنيفات الـ 49 (Categories)
    // ==========================================
    print('\n🏷️ 2. استيراد التصنيفات الدوائية المعرّبة...');
    final catLines = catFile.readAsLinesSync(encoding: utf8);
    final categoryMap = <String, int>{}; // name_ar / name_en -> id

    final insertCatStmt = db.prepare('''
      INSERT INTO categories (name, name_ar, name_en, pharmacy_id, created_at)
      VALUES (?, ?, ?, 1, datetime('now'));
    ''');

    for (var i = 1; i < catLines.length; i++) {
      final line = catLines[i].trim();
      if (line.isEmpty) continue;
      final parts = _parseCsvLine(line);
      if (parts.length < 3) continue;

      final nameEn = parts[1].trim();
      final nameAr = parts[2].trim();
      final displayName = nameAr.isNotEmpty ? nameAr : nameEn;

      // فحص إذا كان موجوداً مسبقاً
      final existing = db.select('SELECT id FROM categories WHERE name = ? OR name_ar = ?;', [displayName, nameAr]);
      int catId;
      if (existing.isNotEmpty) {
        catId = existing.first['id'] as int;
      } else {
        insertCatStmt.execute([displayName, nameAr, nameEn]);
        catId = db.lastInsertRowId;
      }

      if (nameAr.isNotEmpty) categoryMap[nameAr.toLowerCase()] = catId;
      if (nameEn.isNotEmpty) categoryMap[nameEn.toLowerCase()] = catId;
    }
    insertCatStmt.dispose();
    print('   ✓ تم استيراد وتجهيز ${categoryMap.length} تصنيف دوائي.');

    // ==========================================
    // 3. استيراد الشركات المصنعة الـ 881 (Companies)
    // ==========================================
    print('\n🏢 3. استيراد الشركات المصنعة للأدوية...');
    final compLines = compFile.readAsLinesSync(encoding: utf8);
    final companyMap = <String, int>{}; // name_ar / name_en -> id

    final insertCompStmt = db.prepare('''
      INSERT INTO companies (name, name_ar, name_en, country_ar, country_en, pharmacy_id, created_at)
      VALUES (?, ?, ?, ?, ?, 1, datetime('now'));
    ''');

    for (var i = 1; i < compLines.length; i++) {
      final line = compLines[i].trim();
      if (line.isEmpty) continue;
      final parts = _parseCsvLine(line);
      if (parts.length < 3) continue;

      final nameAr = parts[1].trim();
      final nameEn = parts[2].trim();
      final countryAr = parts.length > 3 ? parts[3].trim() : '';
      final countryEn = parts.length > 4 ? parts[4].trim() : '';
      final displayName = nameAr.isNotEmpty ? nameAr : nameEn;
      if (displayName.isEmpty) continue;

      final existing = db.select('SELECT id FROM companies WHERE name = ? OR name_ar = ?;', [displayName, nameAr]);
      int compId;
      if (existing.isNotEmpty) {
        compId = existing.first['id'] as int;
      } else {
        insertCompStmt.execute([displayName, nameAr, nameEn, countryAr, countryEn]);
        compId = db.lastInsertRowId;
      }

      if (nameAr.isNotEmpty) companyMap[nameAr.toLowerCase()] = compId;
      if (nameEn.isNotEmpty) companyMap[nameEn.toLowerCase()] = compId;
    }
    insertCompStmt.dispose();
    print('   ✓ تم استيراد وتجهيز ${companyMap.length} شركة مصنعة.');

    // ==========================================
    // 4. استيراد الموردين والوكلاء الـ 282 (Suppliers)
    // ==========================================
    print('\n🚚 4. استيراد الموردين والوكلاء المعتمدين...');
    final suppLines = suppFile.readAsLinesSync(encoding: utf8);
    final supplierMap = <String, int>{}; // name_ar / name_en / shortName -> id

    final insertSuppStmt = db.prepare('''
      INSERT INTO suppliers (name, name_ar, name_en, short_name, represented_companies, is_active, pharmacy_id, created_at)
      VALUES (?, ?, ?, ?, ?, 1, 1, datetime('now'));
    ''');

    for (var i = 1; i < suppLines.length; i++) {
      final line = suppLines[i].trim();
      if (line.isEmpty) continue;
      final parts = _parseCsvLine(line);
      if (parts.length < 2) continue;

      final nameAr = parts[1].trim();
      final nameEn = parts.length > 2 ? parts[2].trim() : '';
      final shortName = parts.length > 3 ? parts[3].trim() : '';
      final repCompanies = parts.length > 4 ? parts[4].trim() : '';
      final displayName = nameAr.isNotEmpty ? nameAr : (shortName.isNotEmpty ? shortName : nameEn);
      if (displayName.isEmpty) continue;

      final existing = db.select('SELECT id FROM suppliers WHERE name = ? OR name_ar = ?;', [displayName, nameAr]);
      int suppId;
      if (existing.isNotEmpty) {
        suppId = existing.first['id'] as int;
      } else {
        insertSuppStmt.execute([displayName, nameAr, nameEn, shortName, repCompanies]);
        suppId = db.lastInsertRowId;
      }

      if (nameAr.isNotEmpty) supplierMap[nameAr.toLowerCase()] = suppId;
      if (nameEn.isNotEmpty) supplierMap[nameEn.toLowerCase()] = suppId;
      if (shortName.isNotEmpty) supplierMap[shortName.toLowerCase()] = suppId;
    }
    insertSuppStmt.dispose();
    print('   ✓ تم استيراد وتجهيز ${supplierMap.length} مورد ووكيل.');

    // ==========================================
    // 5. استيراد وتحديث الأدوية الـ 30 ألفاً كاملة
    // ==========================================
    print('\n💊 5. استيراد وتحديث كتالوج الأدوية الشامل (نحو 30 ألف دواء)...');
    final medLines = medFile.readAsLinesSync(encoding: utf8);

    // جلب الأدوية الحالية للمطابقة السريعة
    final existingMeds = db.select('SELECT id, name_ar, name_en, barcode, sku FROM medicines;');
    final medNameArMap = <String, int>{};
    final medNameEnMap = <String, int>{};
    final usedBarcodes = <String>{};
    final usedSkus = <String>{};

    for (final row in existingMeds) {
      final id = row['id'] as int;
      final nAr = row['name_ar']?.toString().trim().toLowerCase();
      final nEn = row['name_en']?.toString().trim().toLowerCase();
      final bc = row['barcode']?.toString().trim();
      final sk = row['sku']?.toString().trim();

      if (nAr != null && nAr.isNotEmpty) medNameArMap[nAr] = id;
      if (nEn != null && nEn.isNotEmpty) medNameEnMap[nEn] = id;
      if (bc != null && bc.isNotEmpty) usedBarcodes.add(bc);
      if (sk != null && sk.isNotEmpty) usedSkus.add(sk);
    }

    print('   - عدد الأدوية الحالية في قاعدة البيانات: ${existingMeds.length}');

    final updateMedStmt = db.prepare('''
      UPDATE medicines SET 
        name_en = COALESCE(?, name_en),
        name_scientific = COALESCE(?, name_scientific),
        category_id = COALESCE(?, category_id),
        company_id = COALESCE(?, company_id),
        supplier_id = COALESCE(?, supplier_id),
        reserve_field1 = ?,
        reserve_field2 = ?,
        reserve_field3 = ?,
        selling_price = CASE WHEN selling_price <= 0 THEN ? ELSE selling_price END,
        purchase_price = CASE WHEN purchase_price <= 0 THEN ? ELSE purchase_price END,
        updated_at = datetime('now')
      WHERE id = ?;
    ''');

    final insertMedStmt = db.prepare('''
      INSERT INTO medicines (
        name_ar, name_en, name_scientific, category_id, company_id, supplier_id,
        sku, barcode, unit, medicine_type, purchase_price, selling_price,
        reserve_field1, reserve_field2, reserve_field3,
        reorder_level, is_taxable, tax_rate, is_active, pharmacy_id,
        created_at, updated_at
      ) VALUES (
        ?, ?, ?, ?, ?, ?,
        ?, ?, ?, 0, ?, ?,
        ?, ?, ?,
        5, 1, 0.0, 1, 1,
        datetime('now'), datetime('now')
      );
    ''');

    int updatedCount = 0;
    int insertedCount = 0;

    for (var i = 1; i < medLines.length; i++) {
      final line = medLines[i].trim();
      if (line.isEmpty) continue;
      final parts = _parseCsvLine(line);
      if (parts.length < 3) continue;

      final rawCode = parts[0].trim();
      final nameAr = parts[1].trim();
      final nameEn = parts[2].trim();
      final scNameAr = parts.length > 3 ? parts[3].trim() : '';
      final scNameEn = parts.length > 4 ? parts[4].trim() : '';
      final compNameAr = parts.length > 5 ? parts[5].trim() : '';
      final compNameEn = parts.length > 6 ? parts[6].trim() : '';
      final suppNameAr = parts.length > 8 ? parts[8].trim() : '';
      final suppNameEn = parts.length > 9 ? parts[9].trim() : '';
      final packAndForm = parts.length > 10 ? parts[10].trim() : '';
      final unit = parts.length > 11 && parts[11].trim().isNotEmpty ? parts[11].trim() : 'حبة';
      final priceStr = parts.length > 12 ? parts[12].trim() : '0';
      final bonus = parts.length > 13 ? parts[13].trim() : '';
      final useAr = parts.length > 14 ? parts[14].trim() : '';
      final useEn = parts.length > 15 ? parts[15].trim() : '';
      final catNameAr = parts.length > 16 ? parts[16].trim() : '';
      final catNameEn = parts.length > 17 ? parts[17].trim() : '';

      final effectiveNameAr = nameAr.isNotEmpty ? nameAr : (nameEn.isNotEmpty ? nameEn : 'دواء بدون اسم');
      final effectiveNameEn = nameEn.isNotEmpty ? nameEn : effectiveNameAr;
      final scientificName = scNameAr.isNotEmpty ? scNameAr : scNameEn;

      // مطابقة التصنيف والشركة والمورد
      int? catId;
      if (catNameAr.isNotEmpty) catId = categoryMap[catNameAr.toLowerCase()];
      catId ??= catNameEn.isNotEmpty ? categoryMap[catNameEn.toLowerCase()] : null;

      int? compId;
      if (compNameAr.isNotEmpty) compId = companyMap[compNameAr.toLowerCase()];
      compId ??= compNameEn.isNotEmpty ? companyMap[compNameEn.toLowerCase()] : null;

      int? suppId;
      if (suppNameAr.isNotEmpty) suppId = supplierMap[suppNameAr.toLowerCase()];
      suppId ??= suppNameEn.isNotEmpty ? supplierMap[suppNameEn.toLowerCase()] : null;

      // دواعي الاستعمال والوصفة
      String indications = useAr.isNotEmpty ? useAr : useEn;
      if (indications.isEmpty || indications == 'استخدامات علاجية سريرية') {
        indications = scNameAr.isNotEmpty ? 'علاج يحتوي على ($scNameAr)' : 'دواء مرخص للاستخدام الصيدلاني';
      }

      double price = double.tryParse(priceStr.replaceAll(',', '')) ?? 0.0;
      if (price <= 0) price = 1000.0;
      final purchasePrice = (price * 0.8).roundToDouble();

      // التحقق هل الدواء موجود مسبقاً لتحديثه أم إضافة جديد
      final existingId = medNameArMap[effectiveNameAr.toLowerCase()] ?? 
                         (effectiveNameEn.isNotEmpty ? medNameEnMap[effectiveNameEn.toLowerCase()] : null);

      if (existingId != null) {
        // تحديث الحقول الناقصة والعلاقات والوصفة
        updateMedStmt.execute([
          effectiveNameEn,
          scientificName,
          catId,
          compId,
          suppId,
          indications,
          bonus,
          packAndForm,
          price,
          purchasePrice,
          existingId,
        ]);
        updatedCount++;
      } else {
        // إنشاء رمز باركود و SKU فريد
        String sku = 'SKU-${rawCode.isNotEmpty ? rawCode : i}';
        int skuSuffix = 1;
        while (usedSkus.contains(sku)) {
          sku = 'SKU-${rawCode.isNotEmpty ? rawCode : i}-$skuSuffix';
          skuSuffix++;
        }
        usedSkus.add(sku);

        String barcode = '629${rawCode.padLeft(9, '0')}';
        int bcSuffix = 1;
        while (usedBarcodes.contains(barcode)) {
          barcode = '629${(int.tryParse(rawCode) ?? i) + 100000 + bcSuffix}';
          bcSuffix++;
        }
        usedBarcodes.add(barcode);

        insertMedStmt.execute([
          effectiveNameAr,
          effectiveNameEn,
          scientificName,
          catId,
          compId,
          suppId,
          sku,
          barcode,
          unit,
          purchasePrice,
          price,
          indications,
          bonus,
          packAndForm,
        ]);
        insertedCount++;
        medNameArMap[effectiveNameAr.toLowerCase()] = db.lastInsertRowId;
        if (effectiveNameEn.isNotEmpty) medNameEnMap[effectiveNameEn.toLowerCase()] = db.lastInsertRowId;
      }
    }

    updateMedStmt.dispose();
    insertMedStmt.dispose();

    db.execute('COMMIT;');
    print('   ✓ تم تحديث $updatedCount دواء قائم بالروابط والوصفات والتصنيفات.');
    print('   ✓ تم إدراج $insertedCount دواء جديد بكامل بياناتها.');

    // إعادة بناء فهارس البحث FTS5 إن وجد
    try {
      db.execute('''
        INSERT OR REPLACE INTO medicines_fts(rowid, name_ar, name_scientific, barcode, sku)
        SELECT id, name_ar, name_scientific, barcode, sku FROM medicines;
      ''');
      print('   ✓ تم تحديث فهارس البحث السريع FTS5.');
    } catch (_) {}

    // إحصائيات نهائية
    final finalMedCount = db.select('SELECT count(*) as c FROM medicines;').first['c'];
    final finalCatCount = db.select('SELECT count(*) as c FROM categories;').first['c'];
    final finalCompCount = db.select('SELECT count(*) as c FROM companies;').first['c'];
    final finalSuppCount = db.select('SELECT count(*) as c FROM suppliers;').first['c'];
    final linkedMeds = db.select('SELECT count(*) as c FROM medicines WHERE company_id IS NOT NULL;').first['c'];

    print('\n=========================================');
    print('🎉 ملخص قاعدة البيانات بعد الاستيراد الشامل:');
    print('   - إجمالي الأدوية في النظام: $finalMedCount دواء');
    print('   - إجمالي الشركات المصنعة: $finalCompCount شركة');
    print('   - إجمالي الموردين والوكلاء: $finalSuppCount مورد ووكيل');
    print('   - إجمالي التصنيفات الدوائية: $finalCatCount تصنيف');
    print('   - الأدوية المرتبطة بالشركات والموردين: $linkedMeds دواء');
    print('=========================================\n');

  } catch (e, st) {
    db.execute('ROLLBACK;');
    print('❌ حدث خطأ أثناء الاستيراد وتم التراجع عن التغييرات: $e');
    print(st);
  } finally {
    db.dispose();
  }
}

List<String> _parseCsvLine(String line) {
  final List<String> result = [];
  final StringBuffer current = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      result.add(current.toString().trim());
      current.clear();
    } else {
      current.write(char);
    }
  }
  result.add(current.toString().trim());
  return result;
}
