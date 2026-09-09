/// خدمة تهيئة وزراعة قاعدة بيانات الأدوية الشاملة (29,493 دواء بدون تكرار) - PharmaOS
/// ============================================================================
/// عند أول تشغيل أو عند استيراد البيانات:
/// 1. يقرأ ملف CSV الماستر الموحد (assets/data/Master_Medicines_Complete.csv).
/// 2. يُنشئ التصنيفات والشركات والموردين تلقائياً.
/// 3. يدخل الأدوية بالاسمين العربي والإنجليزي، المادة الفعالة، دواعي الاستعمال، الشركة، والمورد.
/// 4. يتم الإدخال عبر دفعات سريعة (Batched Transaction) خلال ثوانٍ معدودة.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';

import '../di/service_locator.dart';
import '../database/app_database.dart';
import '../../features/medicines/domain/repositories/medicines_repository.dart';
import '../../features/categories/domain/repositories/categories_repository.dart';
import '../../features/companies/domain/repositories/companies_repository.dart';
import '../../features/suppliers/domain/repositories/suppliers_repository.dart';

class MedicineSeedService {
  final MedicinesRepository medicinesRepository;
  final CategoriesRepository categoriesRepository;
  final CompaniesRepository companiesRepository;
  final SuppliersRepository suppliersRepository;

  MedicineSeedService({
    required this.medicinesRepository,
    required this.categoriesRepository,
    required this.companiesRepository,
    required this.suppliersRepository,
  });

  /// يتحقق إذا الكتالوج فارغ أو يحتوي عدداً قليلاً ويملؤه بالدليل الشامل
  Future<SeedResult> seedIfEmpty({bool forceReset = false}) async {
    final db = sl<AppDatabase>();
    final countExp = db.medicines.id.count();
    final query = db.selectOnly(db.medicines)..addColumns([countExp]);
    final row = await query.getSingle();
    final count = row.read(countExp) ?? 0;

    if (count > 5000 && !forceReset) {
      return SeedResult(
        seeded: false,
        count: count,
        message: 'قاعدة البيانات تحتوي على $count دواء بالفعل.',
      );
    }

    return await _seedFromMasterAsset();
  }

  Future<SeedResult> _seedFromMasterAsset() async {
    final db = sl<AppDatabase>();

    try {
      // 1. قراءة الملف الماستر الموحد
      ByteData rawBytes;
      try {
        rawBytes = await rootBundle.load('assets/data/Master_Medicines_Complete.csv');
      } catch (_) {
        rawBytes = await rootBundle.load('assets/data/medicines_catalog.csv');
      }

      String content;
      try {
        content = utf8.decode(rawBytes.buffer.asUint8List(), allowMalformed: true);
      } catch (_) {
        content = latin1.decode(rawBytes.buffer.asUint8List());
      }

      content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(content, fieldDelimiter: ',');

      if (rows.length < 2) {
        return const SeedResult(seeded: false, count: 0, message: 'الملف فارغ');
      }

      final dataRows = rows.skip(1).toList();

      // كاش التصنيفات، الشركات، والموردين
      final categoryCache = <String, int>{};
      final companyCache = <String, int>{};
      final supplierCache = <String, int>{};
      final Set<String> seenIdentifiers = {};

      final existingCats = await db.select(db.categories).get();
      for (final c in existingCats) {
        categoryCache[c.name.trim().toLowerCase()] = c.id;
      }

      final existingComps = await db.select(db.companies).get();
      for (final c in existingComps) {
        companyCache[c.name.trim().toLowerCase()] = c.id;
      }

      final existingSupps = await db.select(db.suppliers).get();
      for (final s in existingSupps) {
        supplierCache[s.name.trim().toLowerCase()] = s.id;
      }

      final List<MedicinesCompanion> insertBatch = [];
      int added = 0;
      int skipped = 0;

      for (final row in dataRows) {
        try {
          String cell(int idx) => (idx < row.length) ? row[idx].toString().trim() : '';

          final medId = cell(0);
          final nameAr = cell(1);
          final nameEn = cell(2);
          final sciAr = cell(3);
          final sciEn = cell(4);
          final compAr = cell(5);
          final compEn = cell(6);
          final countryAr = cell(7);
          final suppAr = cell(8);
          final packForm = cell(10);
          final unit = cell(11);
          final priceStr = cell(12);
          final bonusStr = cell(13);
          final useAr = cell(14);
          final catAr = cell(16);

          final tradeName = nameAr.isNotEmpty ? nameAr : nameEn;
          if (tradeName.isEmpty) {
            skipped++;
            continue;
          }

          // منع التكرار بناءً على كود الدواء والاسم التجاري
          final dedupKey = medId.isNotEmpty ? medId : '${nameAr.toLowerCase()}_${nameEn.toLowerCase()}';
          if (seenIdentifiers.contains(dedupKey)) {
            skipped++;
            continue;
          }
          seenIdentifiers.add(dedupKey);

          // التصنيف
          int? categoryId;
          if (catAr.isNotEmpty && catAr != 'عام') {
            final key = catAr.toLowerCase();
            categoryId = categoryCache[key];
            if (categoryId == null) {
              final catId = await db.into(db.categories).insert(
                    CategoriesCompanion(
                      name: Value(catAr),
                      nameAr: Value(catAr),
                      createdAt: Value(DateTime.now()),
                    ),
                  );
              categoryCache[key] = catId;
              categoryId = catId;
            }
          }

          // الشركة
          int? companyId;
          final compName = compAr.isNotEmpty ? compAr : compEn;
          if (compName.isNotEmpty && compName != 'شركة أدوية عامة') {
            final key = compName.toLowerCase();
            companyId = companyCache[key];
            if (companyId == null) {
              final cId = await db.into(db.companies).insert(
                    CompaniesCompanion(
                      name: Value(compName),
                      countryAr: Value(countryAr.isNotEmpty ? countryAr : 'دولي'),
                      createdAt: Value(DateTime.now()),
                    ),
                  );
              companyCache[key] = cId;
              companyId = cId;
            }
          }

          // المورد
          int? supplierId;
          if (suppAr.isNotEmpty && suppAr != 'وكالة أدوية معتمدة' && suppAr != 'غير متوفر') {
            final key = suppAr.toLowerCase();
            supplierId = supplierCache[key];
            if (supplierId == null) {
              final sId = await db.into(db.suppliers).insert(
                    SuppliersCompanion(
                      name: Value(suppAr),
                      contactInfo: const Value(''),
                      createdAt: Value(DateTime.now()),
                    ),
                  );
              supplierCache[key] = sId;
              supplierId = sId;
            }
          }

          final price = double.tryParse(priceStr) ?? 0.0;
          final sku = 'MED-${medId.isNotEmpty ? medId.padLeft(5, '0') : (added + 1).toString().padLeft(5, '0')}';
          final barcode = '629${medId.isNotEmpty ? medId.padLeft(9, '0') : (added + 1).toString().padLeft(9, '0')}';

          final combinedSci = sciAr.isNotEmpty ? (sciEn.isNotEmpty ? '$sciAr ($sciEn)' : sciAr) : sciEn;
          final finalUnit = unit.isNotEmpty ? unit : 'باكت';

          insertBatch.add(
            MedicinesCompanion(
              nameAr: Value(nameAr.isNotEmpty ? nameAr : tradeName),
              nameEn: Value(nameEn.isNotEmpty ? nameEn : tradeName),
              nameScientific: Value(combinedSci.isNotEmpty ? combinedSci : null),
              categoryId: Value(categoryId),
              companyId: Value(companyId),
              supplierId: Value(supplierId),
              sku: Value(sku),
              barcode: Value(barcode),
              unit: Value(finalUnit),
              purchasePrice: Value(price > 0 ? (price * 0.8) : 0.0),
              sellingPrice: Value(price),
              reorderLevel: const Value(5),
              reserveField1: Value(useAr.isNotEmpty ? useAr : null), // دواعي الاستعمال والوصفات
              reserveField2: Value(compName.isNotEmpty ? '$compName - $packForm' : packForm), // الشركة والعبوة
              reserveField3: Value(bonusStr.isNotEmpty && bonusStr != 'لا يوجد' ? bonusStr : null), // البونص
              isActive: const Value(true),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

          added++;

          // تفريغ في قاعدة البيانات كل 500 صف لتسريع العملية
          if (insertBatch.length >= 500) {
            await db.batch((batch) {
              batch.insertAll(db.medicines, insertBatch, mode: InsertMode.insertOrIgnore);
            });
            insertBatch.clear();
          }
        } catch (_) {
          skipped++;
        }
      }

      // إدخال المتبقي
      if (insertBatch.isNotEmpty) {
        await db.batch((batch) {
          batch.insertAll(db.medicines, insertBatch, mode: InsertMode.insertOrIgnore);
        });
        insertBatch.clear();
      }

      return SeedResult(
        seeded: true,
        count: added,
        message: 'تمت زراعة $added دواء في قاعدة البيانات بنجاح وبدون تكرار.',
      );
    } catch (e) {
      return SeedResult(seeded: false, count: 0, message: 'خطأ أثناء الزراعة: $e');
    }
  }
}

class SeedResult {
  final bool seeded;
  final int count;
  final String message;

  const SeedResult({
    required this.seeded,
    required this.count,
    required this.message,
  });
}
