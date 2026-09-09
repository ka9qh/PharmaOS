import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final dbPath = '$appData\\com.example\\pharmaos\\pharmaos_secure.db';
  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    print('Database not found at $dbPath');
    return;
  }

  print('Database exists at $dbPath. Seeding data...');
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  // قراءة الملف
  final csvFile = File('assets/data/medicines_catalog.csv');
  if (!csvFile.existsSync()) {
    print('CSV file not found!');
    return;
  }

  String content;
  try {
    content = utf8.decode(csvFile.readAsBytesSync(), allowMalformed: true);
  } catch (_) {
    content = latin1.decode(csvFile.readAsBytesSync());
  }
  content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(content, fieldDelimiter: ',');

  final dataRows = rows.skip(1).toList();

  final categoryCache = <String, int>{};
  final companyCache = <String, int>{};

  // تحميل الأقسام الحالية
  final catResult = db.select('SELECT id, name FROM Categories;');
  for (final row in catResult) {
    categoryCache[row['name'].toString().trim().toLowerCase()] = row['id'] as int;
  }

  // تحميل الشركات الحالية
  final comResult = db.select('SELECT id, name FROM Companies;');
  for (final row in comResult) {
    companyCache[row['name'].toString().trim().toLowerCase()] = row['id'] as int;
  }

  int added = 0;
  int skipped = 0;

  db.execute('BEGIN TRANSACTION;');

  try {
    for (final row in dataRows) {
      if (row.isEmpty) continue;
      String cell(int idx) => (idx < row.length) ? row[idx].toString().trim() : '';

      final tradeName = cell(0);
      if (tradeName.isEmpty) {
        skipped++;
        continue;
      }

      final nameAr = cell(1);
      final scientificName = cell(2);
      final categoryName = cell(3);
      final companyName = cell(4);
      final formType = cell(5);
      final country = cell(7);
      final packSize = cell(8);

      final unit = _mapFormToUnit(formType);

      int? categoryId;
      if (categoryName.isNotEmpty) {
        final key = categoryName.trim().toLowerCase();
        categoryId = categoryCache[key];
        if (categoryId == null) {
          db.execute('INSERT INTO Categories (name) VALUES (?);', [categoryName]);
          categoryId = db.lastInsertRowId;
          categoryCache[key] = categoryId;
        }
      }

      int? companyId;
      if (companyName.isNotEmpty) {
        final key = companyName.trim().toLowerCase();
        companyId = companyCache[key];
        if (companyId == null) {
          db.execute('INSERT INTO Companies (name) VALUES (?);', [companyName]);
          companyId = db.lastInsertRowId;
          companyCache[key] = companyId;
        }
      }

      // إدخال الدواء
      final insertAr = nameAr.isNotEmpty ? nameAr : tradeName;
      final insertSci = scientificName.isNotEmpty ? scientificName : null;
      final insertCountry = country.isNotEmpty ? country : null;
      final insertPack = packSize.isNotEmpty ? packSize : null;

      final barcodeVal = 'M-${added.toString().padLeft(6, '0')}';

      db.execute('''
        INSERT INTO Medicines (
          name_ar, name_en, name_scientific, category_id, company_id, 
          unit, purchase_price, selling_price, sku, barcode, is_active, 
          reorder_level, reserve_field1, reserve_field2
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?, 1, 5, ?, ?);
      ''', [
        insertAr, tradeName, insertSci, categoryId, companyId, unit, barcodeVal, barcodeVal, insertCountry, insertPack
      ]);
      added++;
    }
    db.execute('COMMIT;');
    print('تمت إضافة $added دواء بنجاح.');
  } catch (e) {
    db.execute('ROLLBACK;');
    print('خطأ أثناء الإضافة: $e');
  }

  db.dispose();
}

String _mapFormToUnit(String form) {
  final f = form.trim().toLowerCase();
  if (f.contains('tablet') || f.contains('tab') || f.contains('film')) return 'أقراص';
  if (f.contains('capsule') || f.contains('cap')) return 'كبسول';
  if (f.contains('syrup') || f.contains('syr')) return 'شراب';
  if (f.contains('injection') || f.contains('inj') || f.contains('vial') || f.contains('amp')) return 'حقنة';
  if (f.contains('cream') || f.contains('crm')) return 'كريم';
  if (f.contains('ointment') || f.contains('oint')) return 'مرهم';
  if (f.contains('gel')) return 'جل';
  if (f.contains('drop') || f.contains('drp')) return 'قطرة';
  if (f.contains('spray') || f.contains('inhaler')) return 'بخاخ';
  if (f.contains('suppository') || f.contains('supp')) return 'تحاميل';
  if (f.contains('suspension') || f.contains('susp')) return 'معلق';
  if (f.contains('powder') || f.contains('sachet')) return 'مسحوق';
  if (f.contains('solution') || f.contains('sol')) return 'محلول';
  if (f.contains('tube') || f.contains('tub')) return 'أنبوب';
  if (f.contains('strip')) return 'شريط';
  if (f.contains('lotion')) return 'لوشن';
  return 'حبة'; // افتراضي
}
