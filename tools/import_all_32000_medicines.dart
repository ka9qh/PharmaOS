import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final dbPath = '$appData\\com.example\\pharmaos\\pharmaos_secure.db';
  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    print('❌ قاعدة البيانات غير موجودة');
    return;
  }

  print('========================================================');
  print('🚀 استيراد كامل الـ 32 ألف دواء بدون فلترة تكرار 🚀');
  print('========================================================\n');

  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");
  db.execute('PRAGMA foreign_keys = OFF;');

  final basePath = 'C:\\Users\\hp\\Desktop\\اكسل الصيدليه';
  final masterMedFile = File('$basePath\\الجداول_الموحدة_الشاملة\\Master_Medicines_Complete.csv');
  final guideMedFile = File('$basePath\\yemen_pharmacy_guide_medicines.csv');

  // تجهيز خرائط التصنيفات والشركات والموردين للربط الفوري
  final catRows = db.select('SELECT id, name_ar, name_en FROM categories;');
  final categoryMap = <String, int>{};
  for (var c in catRows) {
    if (c['name_ar'] != null) categoryMap[c['name_ar'].toString().trim().toLowerCase()] = c['id'] as int;
    if (c['name_en'] != null) categoryMap[c['name_en'].toString().trim().toLowerCase()] = c['id'] as int;
  }

  final compRows = db.select('SELECT id, name_ar, name_en FROM companies;');
  final companyMap = <String, int>{};
  for (var c in compRows) {
    if (c['name_ar'] != null) companyMap[c['name_ar'].toString().trim().toLowerCase()] = c['id'] as int;
    if (c['name_en'] != null) companyMap[c['name_en'].toString().trim().toLowerCase()] = c['id'] as int;
  }

  final suppRows = db.select('SELECT id, name_ar, name_en, short_name FROM suppliers;');
  final supplierMap = <String, int>{};
  for (var s in suppRows) {
    if (s['name_ar'] != null) supplierMap[s['name_ar'].toString().trim().toLowerCase()] = s['id'] as int;
    if (s['name_en'] != null) supplierMap[s['name_en'].toString().trim().toLowerCase()] = s['id'] as int;
    if (s['short_name'] != null) supplierMap[s['short_name'].toString().trim().toLowerCase()] = s['id'] as int;
  }

  final defaultCatId = categoryMap['أدوية عامة واستخدامات سريرية'] ?? (catRows.isNotEmpty ? catRows.first['id'] as int : 1);

  // جلب كافة الـ Barcodes و SKUs المستخدمة لمنع أي خطأ تكرار
  final existingCodes = db.select('SELECT sku, barcode FROM medicines;');
  final usedSkus = <String>{};
  final usedBarcodes = <String>{};
  for (var r in existingCodes) {
    if (r['sku'] != null) usedSkus.add(r['sku'].toString().trim());
    if (r['barcode'] != null) usedBarcodes.add(r['barcode'].toString().trim());
  }

  final currentCount = existingCodes.length;
  print('✓ عدد الأدوية الحالية في النظام: $currentCount دواء.');

  db.execute('BEGIN TRANSACTION;');

  try {
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

    // ==========================================
    // 1. استيراد باقي أدوية Master_Medicines_Complete.csv
    // ==========================================
    print('\n📦 1. استيراد باقي الأدوية من الملف الموحد الشامل (Master_Medicines_Complete)...');
    final masterLines = masterMedFile.readAsLinesSync();
    int masterInserted = 0;

    // نبدأ من بعد الأدوية التي تم إدخالها سابقاً أو نتحقق من عدم وجود السطر
    for (var i = 1; i < masterLines.length; i++) {
      final line = masterLines[i].trim();
      if (line.isEmpty) continue;
      final parts = _parseCsvLine(line);
      if (parts.length < 3) continue;

      // إذا كان رقم السطر أقل من أو يساوي الأدوية الحالية الأولية، نتجاوزه لأنه موجود مسبقاً
      if (i <= currentCount) continue;

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

      final effectiveNameAr = nameAr.isNotEmpty ? nameAr : (nameEn.isNotEmpty ? nameEn : 'دواء صيدلاني');
      final effectiveNameEn = nameEn.isNotEmpty ? nameEn : effectiveNameAr;
      final scientificName = scNameAr.isNotEmpty ? scNameAr : scNameEn;

      // التصنيف
      int? catId;
      if (catNameAr.isNotEmpty) catId = categoryMap[catNameAr.toLowerCase()];
      catId ??= catNameEn.isNotEmpty ? categoryMap[catNameEn.toLowerCase()] : null;
      catId ??= defaultCatId;

      // الشركة
      int? compId;
      if (compNameAr.isNotEmpty) compId = companyMap[compNameAr.toLowerCase()];
      compId ??= compNameEn.isNotEmpty ? companyMap[compNameEn.toLowerCase()] : null;

      // المورد
      int? suppId;
      if (suppNameAr.isNotEmpty) suppId = supplierMap[suppNameAr.toLowerCase()];
      suppId ??= suppNameEn.isNotEmpty ? supplierMap[suppNameEn.toLowerCase()] : null;

      String indications = useAr.isNotEmpty ? useAr : useEn;
      if (indications.isEmpty || indications == 'استخدامات علاجية سريرية') {
        indications = scNameAr.isNotEmpty ? 'علاج يحتوي على ($scNameAr)' : 'دواء مرخص للاستخدام الصيدلاني';
      }

      double price = double.tryParse(priceStr.replaceAll(',', '')) ?? 0.0;
      if (price <= 0) price = 1200.0;
      final purchasePrice = (price * 0.8).roundToDouble();

      // توليد باركود و SKU فريد تماماً
      String sku = 'SKU-${rawCode.isNotEmpty ? rawCode : i}-$i';
      while (usedSkus.contains(sku)) {
        sku = 'SKU-${rawCode.isNotEmpty ? rawCode : i}-${DateTime.now().microsecond}-$i';
      }
      usedSkus.add(sku);

      String barcode = '629${i.toString().padLeft(9, '0')}';
      while (usedBarcodes.contains(barcode)) {
        barcode = '629${(i + 100000).toString().padLeft(9, '0')}';
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
      masterInserted++;
    }
    print('   ✓ تم إدراج $masterInserted دواء إضافي من الملف الموحد الشامل.');

    // ==========================================
    // 2. استيراد أدوية دليل الصيدلية اليمني (yemen_pharmacy_guide_medicines.csv)
    // ==========================================
    print('\n🇾🇪 2. استيراد أدوية دليل الصيدلية اليمني (Yemen Pharmacy Guide)...');
    final guideLines = guideMedFile.readAsLinesSync();
    int guideInserted = 0;

    for (var i = 1; i < guideLines.length; i++) {
      final line = guideLines[i].trim();
      if (line.isEmpty) continue;
      final parts = _parseCsvLine(line);
      if (parts.length < 2) continue;

      final name = parts[0].trim();
      final scName = parts.length > 1 ? parts[1].trim() : '';
      final catName = parts.length > 2 ? parts[2].trim() : '';
      final compName = parts.length > 3 ? parts[3].trim() : '';
      final form = parts.length > 4 ? parts[4].trim() : '';
      final dosage = parts.length > 5 ? parts[5].trim() : '';
      final origin = parts.length > 6 ? parts[6].trim() : '';
      final packSize = parts.length > 7 ? parts[7].trim() : '';

      if (name.isEmpty) continue;

      // مطابقة أو تصنيف
      int? catId;
      if (catName.isNotEmpty) catId = categoryMap[catName.toLowerCase()];
      catId ??= defaultCatId;

      int? compId;
      if (compName.isNotEmpty) compId = companyMap[compName.toLowerCase()];

      final indications = dosage.isNotEmpty 
          ? 'الجرعة والاستعمال: $dosage' 
          : (scName.isNotEmpty ? 'علاج يحتوي على التركيبة: $scName' : 'دواء مسجل في دليل الأدوية اليمني');

      final packAndForm = [form, packSize, origin].where((s) => s.isNotEmpty).join(' - ');

      String sku = 'YPG-$i';
      while (usedSkus.contains(sku)) {
        sku = 'YPG-$i-${DateTime.now().microsecond}';
      }
      usedSkus.add(sku);

      String barcode = '628${i.toString().padLeft(9, '0')}';
      while (usedBarcodes.contains(barcode)) {
        barcode = '628${(i + 200000).toString().padLeft(9, '0')}';
      }
      usedBarcodes.add(barcode);

      insertMedStmt.execute([
        name,
        name,
        scName,
        catId,
        compId,
        null,
        sku,
        barcode,
        form.isNotEmpty ? form : 'باكت',
        1000.0,
        1250.0,
        indications,
        'متوفر',
        packAndForm,
      ]);
      guideInserted++;
    }

    insertMedStmt.dispose();
    db.execute('COMMIT;');

    print('   ✓ تم إدراج $guideInserted دواء من دليل الصيدلية اليمني.');

    // إعادة بناء فهارس البحث FTS5
    try {
      db.execute('''
        INSERT OR REPLACE INTO medicines_fts(rowid, name_ar, name_scientific, barcode, sku)
        SELECT id, name_ar, name_scientific, barcode, sku FROM medicines;
      ''');
      print('   ✓ تم تحديث فهارس البحث السريع FTS5 لكافة الأدوية.');
    } catch (_) {}

    final totalMeds = db.select('SELECT count(*) as c FROM medicines;').first['c'];
    print('\n========================================================');
    print('🎉 النتيجة النهائية: إجمالي الأدوية في النظام الآن: $totalMeds دواء كامل!');
    print('========================================================\n');

  } catch (e, st) {
    db.execute('ROLLBACK;');
    print('❌ خطأ أثناء الاستيراد الشامل: $e');
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
