// استيراد الأدوية بالجملة من ملف Excel أو CSV (فاتورة/كتالوج مورّد)
// ============================================================================
// لا يحاول "تخمين" تلقائيًا بشكل كامل: يعرض معاينة للأعمدة الفعلية بالملف
// ويترك المستخدم يربط كل عمود بحقل النظام المناسب (راجع ExcelImportScreen)،
// حتى لا يُخطئ الاستيراد في تفسير عمود بطريقة تُدخل بيانات دواء خاطئة.
//
// تحديث: أُضيف دعم CSV كمسار أساسي موثوق. ملفات Excel (.xlsx) المولَّدة من
// مكتبات غير Microsoft (مثل openpyxl بايثون التي استخدمتها لملفات البذر)
// تسبّبت بخطأ "Null check operator used on a null value" عند فك ترميزها عبر
// حزمة excel في Flutter - على الأرجح تعارض توافقية بين طريقة كتابة openpyxl
// وطريقة قراءة الحزمة الداخلية (لم أستطع تتبع السبب الدقيق داخل الحزمة بدون
// بيئة Flutter فعلية لديّ لأختبرها). CSV نص عادي بسيط ولا يعتمد على أي تنسيق
// ثنائي معقّد، فهو أوثق بكثير - لذلك حوّلت كل ملفات البذر لـCSV. دعم .xlsx
// بقي متاحًا لملفات مورّديك المستقبلية، لكن إن واجهت نفس الخطأ معها، اطلب من
// موزّعك نسخة CSV بدل Excel، أو افتح الملف في Excel واحفظه كـ"CSV UTF-8".

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;

import '../../features/medicines/domain/repositories/medicines_repository.dart';
import '../../features/categories/domain/repositories/categories_repository.dart';
import '../../features/companies/domain/repositories/companies_repository.dart';
import '../../features/suppliers/domain/repositories/suppliers_repository.dart';
import 'medicine_translation_service.dart';

/// الحقول التي يمكن ربط عمود بها. name إلزامي، الباقي اختياري.
enum ImportField {
  name, // English Name
  scientificName,
  supplier,
  company,
  category,
  barcode,
  unit,
  purchasePrice,
  sellingPrice,
  qtyPerPack,
  qtyPerStrip,
  reorderLevel,
  uses,         // reserveField1
  format,       // reserveField2
  bonus,        // reserveField3
  skip, // تجاهل هذا العمود
}

class ExcelSheetPreview {
  final List<String> headers;
  final List<List<String>> sampleRows; // أول 5 صفوف بيانات فقط للمعاينة
  final List<List<String>> allDataRows; // كل صفوف البيانات (بدون رأس الجدول)

  const ExcelSheetPreview({
    required this.headers,
    required this.sampleRows,
    required this.allDataRows,
  });
}

class ImportSummary {
  final int added;
  final int skippedDuplicateBarcode;
  final int skippedEmptyName;
  final int errors;

  const ImportSummary({
    required this.added,
    required this.skippedDuplicateBarcode,
    required this.skippedEmptyName,
    required this.errors,
  });
}

class MedicineExcelImportService {
  final MedicinesRepository medicinesRepository;
  final CategoriesRepository categoriesRepository;
  final CompaniesRepository companiesRepository;
  final SuppliersRepository suppliersRepository;

  MedicineExcelImportService({
    required this.medicinesRepository,
    required this.categoriesRepository,
    required this.companiesRepository,
    required this.suppliersRepository,
  });

  /// يقرأ أول ورقة (Sheet) من ملف Excel (.xlsx) ويحوّلها لنصوص خام للمعاينة.
  /// إن فشل فك الترميز (ملف من مصدر غير متوافق تمامًا مع الحزمة)، يُطلق خطأ
  /// واضحًا يقترح صراحة تجربة CSV بدلاً منه.
  ExcelSheetPreview readSheet(List<int> bytes) {
    final xls.Excel workbook;
    try {
      workbook = xls.Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception(
          'تعذر فتح ملف Excel هذا (قد يكون غير متوافق تمامًا مع صيغة .xlsx القياسية). '
          'جرّب فتحه في برنامج Excel واحفظه من جديد كـ"CSV UTF-8 (Comma delimited)"، '
          'ثم ارفع ملف الـCSV بدلاً منه - أكثر موثوقية. الخطأ الأصلي: $e');
    }
    if (workbook.tables.isEmpty) {
      throw Exception('الملف لا يحتوي أي ورقة بيانات (Sheet)');
    }
    final sheet = workbook.tables.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) {
      throw Exception('الورقة فارغة');
    }

    String cellText(xls.Data? cell) => cell?.value?.toString().trim() ?? '';

    final headers = rows.first.map(cellText).toList();
    final dataRows = rows.skip(1).map((r) => r.map(cellText).toList()).toList();

    return ExcelSheetPreview(
      headers: headers,
      sampleRows: dataRows.take(5).toList(),
      allDataRows: dataRows,
    );
  }

  /// يقرأ ملف CSV (نص عادي، مفصول بفواصل) - المسار الموصى به لأنه لا يعتمد
  /// على فك ترميز صيغة ثنائية معقّدة، فهو أكثر توافقية وموثوقية من .xlsx.
  ExcelSheetPreview readCsv(String content) {
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(content, fieldDelimiter: ',');
    if (rows.isEmpty) {
      throw Exception('الملف فارغ');
    }

    String cellText(dynamic cell) => cell?.toString().trim() ?? '';

    final headers = rows.first.map(cellText).toList();
    final dataRows = rows
        .skip(1)
        .where((r) => r.any((c) => cellText(c).isNotEmpty)) // تخطي أي صف فارغ تمامًا
        .map((r) => r.map(cellText).toList())
        .toList();

    return ExcelSheetPreview(
      headers: headers,
      sampleRows: dataRows.take(5).toList(),
      allDataRows: dataRows,
    );
  }

  /// ينفّذ الاستيراد الفعلي حسب ربط الأعمدة الذي اختاره المستخدم.
  /// columnMapping: فهرس العمود (index في headers) → الحقل الذي يمثّله.
  Future<ImportSummary> import({
    required List<List<String>> dataRows,
    required Map<int, ImportField> columnMapping,
    required String defaultUnit,
    required int defaultReorderLevel,
  }) async {
    int added = 0, skippedDup = 0, skippedEmpty = 0, errors = 0;

    // ذاكرة تخزين مؤقت محلية لتفادي إنشاء نفس الشركة/التصنيف عدة مرات خلال
    // نفس عملية الاستيراد (بحث متكرر بالاسم في قاعدة بيانات صغيرة نسبيًا آمن).
    final companyCache = <String, int>{};
    final categoryCache = <String, int>{};
    final supplierCache = <String, int>{};

    int? indexOf(ImportField field) {
      for (final entry in columnMapping.entries) {
        if (entry.value == field) return entry.key;
      }
      return null;
    }

    final nameIdx = indexOf(ImportField.name);
    final sciIdx = indexOf(ImportField.scientificName);
    final supplierIdx = indexOf(ImportField.supplier);
    final companyIdx = indexOf(ImportField.company);
    final categoryIdx = indexOf(ImportField.category);
    final barcodeIdx = indexOf(ImportField.barcode);
    final unitIdx = indexOf(ImportField.unit);
    final purchaseIdx = indexOf(ImportField.purchasePrice);
    final sellingIdx = indexOf(ImportField.sellingPrice);
    final qtyPackIdx = indexOf(ImportField.qtyPerPack);
    final qtyStripIdx = indexOf(ImportField.qtyPerStrip);
    final reorderIdx = indexOf(ImportField.reorderLevel);
    final usesIdx = indexOf(ImportField.uses);
    final formatIdx = indexOf(ImportField.format);
    final bonusIdx = indexOf(ImportField.bonus);

    String cell(List<String> row, int? idx) =>
        (idx != null && idx < row.length) ? row[idx].trim() : '';

    double parsePrice(String raw) => double.tryParse(raw.replaceAll(',', '')) ?? 0;
    int parseInt(String raw) => int.tryParse(raw.replaceAll(',', '')) ?? 0;

    for (final row in dataRows) {
      final name = cell(row, nameIdx);
      if (name.isEmpty) {
        skippedEmpty++;
        continue;
      }

      final barcode = cell(row, barcodeIdx);
      if (barcode.isNotEmpty) {
        final existing = await medicinesRepository.getByBarcode(barcode);
        if (existing != null) {
          skippedDup++;
          continue;
        }
      }

      try {
        int? supplierId;
        final supplierName = cell(row, supplierIdx);
        if (supplierName.isNotEmpty) {
          supplierId = supplierCache[supplierName];
          if (supplierId == null) {
            final created = await suppliersRepository.create(
              name: supplierName,
              contactInfo: '',
            );
            supplierId = created.id;
            supplierCache[supplierName] = supplierId;
          }
        }

        int? companyId;
        final companyName = cell(row, companyIdx);
        if (companyName.isNotEmpty) {
          companyId = companyCache[companyName];
          if (companyId == null) {
            final created = await companiesRepository.create(companyName);
            companyId = created.id;
            companyCache[companyName] = companyId;
          }
        }

        int? categoryId;
        final categoryName = cell(row, categoryIdx);
        if (categoryName.isNotEmpty) {
          categoryId = categoryCache[categoryName];
          if (categoryId == null) {
            final created = await categoriesRepository.create(categoryName);
            categoryId = created.id;
            categoryCache[categoryName] = categoryId;
          }
        }

        final translatedAr = MedicineTranslationService.translate(name);

        await medicinesRepository.create(
          nameAr: translatedAr,
          nameEn: name,
          nameScientific: cell(row, sciIdx).isEmpty ? null : cell(row, sciIdx),
          categoryId: categoryId,
          companyId: companyId,
          supplierId: supplierId,
          unit: cell(row, unitIdx).isEmpty ? defaultUnit : cell(row, unitIdx),
          purchasePrice: parsePrice(cell(row, purchaseIdx)),
          sellingPrice: parsePrice(cell(row, sellingIdx)),
          qtyPerPack: qtyPackIdx != null && cell(row, qtyPackIdx).isNotEmpty
              ? parseInt(cell(row, qtyPackIdx))
              : null,
          qtyPerStrip: qtyStripIdx != null && cell(row, qtyStripIdx).isNotEmpty
              ? parseInt(cell(row, qtyStripIdx))
              : null,
          reorderLevel: reorderIdx != null && cell(row, reorderIdx).isNotEmpty
              ? parseInt(cell(row, reorderIdx))
              : defaultReorderLevel,
          barcode: barcode.isEmpty ? null : barcode,
          reserveField1: usesIdx != null && cell(row, usesIdx).isNotEmpty ? cell(row, usesIdx) : null,
          reserveField2: formatIdx != null && cell(row, formatIdx).isNotEmpty ? cell(row, formatIdx) : null,
          reserveField3: bonusIdx != null && cell(row, bonusIdx).isNotEmpty ? cell(row, bonusIdx) : null,
        );
        added++;
      } catch (_) {
        errors++;
      }
    }

    return ImportSummary(
      added: added,
      skippedDuplicateBarcode: skippedDup,
      skippedEmptyName: skippedEmpty,
      errors: errors,
    );
  }
}
