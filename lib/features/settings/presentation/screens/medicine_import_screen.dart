// استيراد الأدوية بالجملة من ملف Excel - يُفتح من الإعدادات
// ============================================================================
// يتطلب حزمة file_picker (جديدة على المشروع - أضفها في pubspec.yaml، راجع
// docs/PATCH_NOTES_2026_08_IMPORT.md). حزمة excel كانت موجودة مسبقًا.
//
// التدفق: اختيار ملف ← معاينة أول عمود ورأس الجدول ← ربط كل عمود بحقل النظام
// (اسم الدواء إلزامي، الباقي اختياري) ← تأكيد الاستيراد ← ملخص النتيجة.
// لا يوجد تخمين كامل تلقائي للأعمدة عمدًا - فقط اقتراح مبدئي حسب اسم العمود،
// يبقى القرار النهائي للمستخدم لتفادي إدخال بيانات دواء خاطئة.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/medicine_excel_import_service.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../categories/domain/repositories/categories_repository.dart';
import '../../../companies/domain/repositories/companies_repository.dart';
import '../../../suppliers/domain/repositories/suppliers_repository.dart';

class MedicineImportScreen extends StatefulWidget {
  const MedicineImportScreen({super.key});

  @override
  State<MedicineImportScreen> createState() => _MedicineImportScreenState();
}

class _MedicineImportScreenState extends State<MedicineImportScreen> {
  late final _service = MedicineExcelImportService(
    medicinesRepository: sl<MedicinesRepository>(),
    categoriesRepository: sl<CategoriesRepository>(),
    companiesRepository: sl<CompaniesRepository>(),
    suppliersRepository: sl<SuppliersRepository>(),
  );

  String? _fileName;
  ExcelSheetPreview? _preview;
  final Map<int, ImportField> _mapping = {};
  bool _isBusy = false;
  String? _error;
  ImportSummary? _summary;

  // كلمات مفتاحية للتخمين المبدئي لعنوان كل عمود (عربي/إنجليزي شائع) - اقتراح
  // فقط، المستخدم يراجعه ويغيّره كما يشاء قبل التأكيد.
  static const _guessKeywords = <ImportField, List<String>>{
    ImportField.name: ['اسم الدواء', 'الاسم التجاري', 'اسم', 'name', 'product'],
    ImportField.scientificName: ['الاسم العلمي', 'المادة الفعالة', 'scientific', 'generic'],
    ImportField.supplier: ['المورد', 'مورد', 'الموزع', 'supplier', 'vendor'],
    ImportField.company: ['الشركة', 'شركة', 'company', 'manufacturer'],
    ImportField.category: ['التصنيف', 'الفئة', 'category', 'class'],
    ImportField.barcode: ['باركود', 'barcode'],
    ImportField.unit: ['الوحدة', 'unit'],
    ImportField.purchasePrice: ['سعر الشراء', 'شراء', 'purchase', 'cost'],
    ImportField.sellingPrice: ['سعر البيع', 'بيع', 'sell', 'price'],
    ImportField.qtyPerPack: ['الكمية في العلبة', 'كمية العلبة', 'pack'],
    ImportField.qtyPerStrip: ['الكمية في الشريط', 'كمية الشريط', 'strip'],
    ImportField.reorderLevel: ['حد التنبيه', 'الحد الأدنى', 'reorder', 'min'],
    ImportField.uses: ['دواعي الاستعمال', 'استخدام', 'uses', 'indications'],
    ImportField.format: ['التعبئة', 'الشكل الصيدلاني', 'format', 'type'],
    ImportField.bonus: ['بونص', 'مجاني', 'bonus'],
  };

  ImportField _guessFieldFor(String header) {
    final h = header.trim().toLowerCase();
    for (final entry in _guessKeywords.entries) {
      for (final kw in entry.value) {
        if (h.contains(kw.toLowerCase())) return entry.key;
      }
    }
    return ImportField.skip;
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _summary = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'تعذر قراءة محتوى الملف');
      return;
    }

    final isCsv = file.name.toLowerCase().endsWith('.csv');

    try {
      final preview =
          isCsv ? _service.readCsv(_decodeCsvBytes(bytes)) : _service.readSheet(bytes);
      _mapping.clear();
      for (var i = 0; i < preview.headers.length; i++) {
        _mapping[i] = _guessFieldFor(preview.headers[i]);
      }
      setState(() {
        _fileName = file.name;
        _preview = preview;
      });
    } catch (e) {
      setState(() => _error = isCsv
          ? 'تعذر قراءة ملف الـCSV: $e'
          : 'تعذر قراءة الملف كـExcel صالح: $e');
    }
  }

  /// فك ترميز بايتات CSV كنص UTF-8 (لازم لدعم النص العربي بشكل صحيح) - يتجاوز
  /// BOM إن وُجد (شائع في ملفات CSV المحفوظة من Excel/Python).
  String _decodeCsvBytes(List<int> bytes) {
    var b = bytes;
    if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
      b = b.sublist(3);
    }
    return utf8.decode(b, allowMalformed: true);
  }

  Future<void> _confirmImport() async {
    final preview = _preview;
    if (preview == null) return;

    final hasName = _mapping.values.contains(ImportField.name);
    if (!hasName) {
      setState(() => _error = 'يجب ربط عمود واحد على الأقل بحقل "اسم الدواء"');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      final summary = await _service.import(
        dataRows: preview.allDataRows,
        columnMapping: _mapping,
        defaultUnit: 'حبة',
        defaultReorderLevel: 10,
      );
      setState(() => _summary = summary);
    } catch (e) {
      setState(() => _error = 'فشل الاستيراد: $e');
    } finally {
      setState(() => _isBusy = false);
    }
  }

  String _fieldLabel(ImportField field) {
    switch (field) {
      case ImportField.name:
        return 'اسم الدواء (إنجليزي/تجاري) *';
      case ImportField.scientificName:
        return 'الاسم العلمي';
      case ImportField.supplier:
        return 'المورّد';
      case ImportField.company:
        return 'الشركة المصنعة';
      case ImportField.category:
        return 'التصنيف';
      case ImportField.barcode:
        return 'الباركود';
      case ImportField.unit:
        return 'الوحدة الأساسية';
      case ImportField.purchasePrice:
        return 'سعر الشراء';
      case ImportField.sellingPrice:
        return 'سعر البيع';
      case ImportField.qtyPerPack:
        return 'الكمية في العلبة';
      case ImportField.qtyPerStrip:
        return 'الكمية/شريط';
      case ImportField.reorderLevel:
        return 'حد التنبيه';
      case ImportField.uses:
        return 'دواعي الاستعمال';
      case ImportField.format:
        return 'التعبئة والشكل';
      case ImportField.bonus:
        return 'البونص';
      case ImportField.skip:
        return 'تجاهل هذا العمود';
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final summary = _summary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('استيراد الأدوية من Excel')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text(
                'اختر ملف Excel من مورّدك (فاتورة أو كتالوج أسعار). العمود الوحيد '
                'الإلزامي هو اسم الدواء - الأعمدة الأخرى اختيارية.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isBusy ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_fileName == null ? 'اختيار ملف Excel' : 'الملف: $_fileName'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              if (summary != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('نتيجة الاستيراد', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('✅ أُضيف: ${summary.added}'),
                        Text('⏭️ متخطى (باركود مكرر): ${summary.skippedDuplicateBarcode}'),
                        Text('⏭️ متخطى (بدون اسم): ${summary.skippedEmptyName}'),
                        if (summary.errors > 0)
                          Text('⚠️ أخطاء: ${summary.errors}', style: const TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
                ),
              ] else if (preview != null) ...[
                const SizedBox(height: 20),
                Text('عدد صفوف البيانات في الملف: ${preview.allDataRows.length}'),
                const SizedBox(height: 8),
                const Text('اربط كل عمود بالحقل المناسب:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List.generate(preview.headers.length, (i) {
                  final sample = preview.sampleRows.isNotEmpty && i < preview.sampleRows.first.length
                      ? preview.sampleRows.first[i]
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${preview.headers[i].isEmpty ? "عمود ${i + 1}" : preview.headers[i]}\n'
                            'مثال: $sample',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: DropdownButton<ImportField>(
                            isExpanded: true,
                            value: _mapping[i] ?? ImportField.skip,
                            items: ImportField.values
                                .map((f) => DropdownMenuItem(value: f, child: Text(_fieldLabel(f))))
                                .toList(),
                            onChanged: (value) => setState(() => _mapping[i] = value!),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isBusy ? null : _confirmImport,
                    child: _isBusy
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('استيراد ${preview.allDataRows.length} صف'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
