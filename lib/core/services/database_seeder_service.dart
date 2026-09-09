// خدمة تهيئة وزراعة قاعدة البيانات الشاملة الموحدة للأدوية والشركات والموردين - PharmaOS
// تدعم زراعة أكثر من 30,000 دواء بدون تكرار مع كافة التفاصيل والترجمات ودواعي الاستعمال.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';
import '../../features/medicines/domain/repositories/medicines_repository.dart';
import '../../features/companies/domain/repositories/companies_repository.dart';
import '../../features/suppliers/domain/repositories/suppliers_repository.dart';
import '../../features/wallets/domain/repositories/wallets_repository.dart';

class DatabaseSeederService {
  final AppDatabase _db;
  final MedicinesRepository _medicinesRepo;
  final CompaniesRepository _companiesRepo;
  final SuppliersRepository _suppliersRepo;
  final WalletsRepository _walletsRepo;

  DatabaseSeederService(
    this._db,
    this._medicinesRepo,
    this._companiesRepo,
    this._suppliersRepo,
    this._walletsRepo,
  );

  /// تهيئة المحافظ الإلكترونية الافتراضية
  Future<void> seedDefaultWalletsIfEmpty() async {
    try {
      final existing = await _walletsRepo.getAll();
      if (existing.isEmpty) {
        final defaultWallets = [
          'كريمي جوال (Kuraimi)',
          'ون كاش (OneCash)',
          'جوالي (Jawali)',
          'فلوسك (Floosak)',
          'بي كاش (BCash)',
          'محفظة كاش (Cash)',
          'شامل موني (Shamel Money)',
          'موبايل موني (Mobile Money)',
          'يمن كاش (Yemen Cash)',
        ];

        for (var name in defaultWallets) {
          await _walletsRepo.create(name);
        }
        debugPrint('✅ تم تهيئة المحافظ الإلكترونية الافتراضية بنجاح.');
      }
    } catch (e) {
      debugPrint('⚠️ خطأ أثناء تهيئة المحافظ: $e');
    }
  }

  /// يزرع قاعدة البيانات بجميع الملفات المرفقة (30 ألف دواء بدون تكرار)
  Future<void> seedDatabaseIfEmpty({bool forceReset = false}) async {
    try {
      await seedDefaultWalletsIfEmpty();

      if (!forceReset) {
        final totalCountRow = await _db.customSelect('SELECT COUNT(*) as c FROM medicines').getSingle();
        final count = totalCountRow.data['c'] as int? ?? 0;
        if (count >= 25000) {
          debugPrint('✅ قاعدة البيانات تحتوي بالفعل على $count دواء كامل، لا حاجة لإعادة الزراعة.');
          return;
        }
      }

      debugPrint('🚀 جاري زراعة كتالوج الأدوية الشامل (29,493 دواء موحد بدون تكرار)...');

      // تنظيف الجداول القديمة للأدوية
      await _db.customStatement('DROP TRIGGER IF EXISTS medicines_fts_ai;');
      await _db.customStatement('DROP TRIGGER IF EXISTS medicines_fts_ad;');
      await _db.customStatement('DROP TRIGGER IF EXISTS medicines_fts_au;');
      await _db.customStatement('DROP TABLE IF EXISTS medicines_fts;');

      await _db.delete(_db.medicineUnits).go();
      await _db.delete(_db.medicines).go();
      await _db.delete(_db.categories).go();

      // 1. زراعة الشركات
      String compString = '';
      try {
        compString = await rootBundle.loadString('assets/data/Master_Companies_Complete.csv');
      } catch (_) {
        compString = await rootBundle.loadString('assets/data/Companies_all.csv');
      }
      final compRows = const CsvToListConverter().convert(compString);
      final companyNameMap = <String, int>{};
      final companiesToInsert = <CompaniesCompanion>[];
      int compSeq = 1;

      for (var r in compRows.skip(1)) {
        if (r.isEmpty) continue;
        final nameAr = r.length > 1 ? r[1]?.toString().trim() ?? '' : '';
        final nameEn = r.length > 2 ? r[2]?.toString().trim() ?? '' : '';
        final countryAr = r.length > 3 ? r[3]?.toString().trim() ?? '' : '';
        final countryEn = r.length > 4 ? r[4]?.toString().trim() ?? '' : '';
        final finalName = nameAr.isNotEmpty ? nameAr : nameEn;
        if (finalName.isEmpty || companyNameMap.containsKey(finalName.toLowerCase())) continue;

        final newId = compSeq++;
        companyNameMap[finalName.toLowerCase()] = newId;
        companiesToInsert.add(CompaniesCompanion.insert(
          id: drift.Value(newId),
          name: finalName,
          nameAr: drift.Value(nameAr.isNotEmpty ? nameAr : null),
          nameEn: drift.Value(nameEn.isNotEmpty ? nameEn : null),
          countryAr: drift.Value(countryAr.isNotEmpty ? countryAr : null),
          countryEn: drift.Value(countryEn.isNotEmpty ? countryEn : null),
        ));
      }

      if (companiesToInsert.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.companies, companiesToInsert, mode: drift.InsertMode.insertOrIgnore);
        });
      }

      // 2. زراعة الموردين
      String suppString = '';
      try {
        suppString = await rootBundle.loadString('assets/data/Master_Suppliers_Complete.csv');
      } catch (_) {
        suppString = await rootBundle.loadString('assets/data/Proxies_all.csv');
      }
      final suppRows = const CsvToListConverter().convert(suppString);
      final supplierNameMap = <String, int>{};
      final suppliersToInsert = <SuppliersCompanion>[];
      int suppSeq = 1;

      for (var r in suppRows.skip(1)) {
        if (r.isEmpty) continue;
        final nameAr = r.length > 1 ? r[1]?.toString().trim() ?? '' : '';
        final nameEn = r.length > 2 ? r[2]?.toString().trim() ?? '' : '';
        final shortName = r.length > 3 ? r[3]?.toString().trim() ?? '' : '';
        final repComp = r.length > 4 ? r[4]?.toString().trim() ?? '' : '';
        final finalName = nameAr.isNotEmpty ? nameAr : nameEn;
        if (finalName.isEmpty || supplierNameMap.containsKey(finalName.toLowerCase())) continue;

        final newId = suppSeq++;
        supplierNameMap[finalName.toLowerCase()] = newId;
        suppliersToInsert.add(SuppliersCompanion.insert(
          id: drift.Value(newId),
          name: finalName,
          nameAr: drift.Value(nameAr.isNotEmpty ? nameAr : null),
          nameEn: drift.Value(nameEn.isNotEmpty ? nameEn : null),
          shortName: drift.Value(shortName.isNotEmpty ? shortName : null),
          representedCompanies: drift.Value(repComp.isNotEmpty ? repComp : null),
        ));
      }

      if (suppliersToInsert.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.suppliers, suppliersToInsert, mode: drift.InsertMode.insertOrIgnore);
        });
      }

      // 3. زراعة التصنيفات
      String catString = '';
      try {
        catString = await rootBundle.loadString('assets/data/Master_Categories_Complete.csv');
      } catch (_) {}
      final catRows = catString.isNotEmpty ? const CsvToListConverter().convert(catString) : <List<dynamic>>[];
      final categoryNameMap = <String, int>{};
      final categoriesToInsert = <CategoriesCompanion>[];
      int catSeq = 1;

      for (var r in catRows.skip(1)) {
        if (r.isEmpty) continue;
        final catEn = r.length > 1 ? r[1]?.toString().trim() ?? '' : '';
        final catArRaw = r.length > 2 ? r[2]?.toString().trim() ?? '' : '';
        final catAr = catArRaw.isNotEmpty ? catArRaw : catEn;
        if (catAr.isEmpty || categoryNameMap.containsKey(catAr.toLowerCase())) continue;

        final newId = catSeq++;
        categoryNameMap[catAr.toLowerCase()] = newId;
        categoriesToInsert.add(CategoriesCompanion.insert(
          id: drift.Value(newId),
          name: catAr,
          nameAr: drift.Value(catArRaw.isNotEmpty ? catArRaw : null),
          nameEn: drift.Value(catEn.isNotEmpty ? catEn : null),
        ));
      }

      if (categoriesToInsert.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.categories, categoriesToInsert, mode: drift.InsertMode.insertOrIgnore);
        });
      }

      // 4. زراعة الأدوية من الملف الماستر الشامل (Master_Medicines_Complete.csv)
      String medsString = '';
      try {
        medsString = await rootBundle.loadString('assets/data/Master_Medicines_Complete.csv');
      } catch (_) {
        medsString = await rootBundle.loadString('assets/data/Drugs_all.csv');
      }

      final medsRows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(medsString);
      final medicinesToInsert = <MedicinesCompanion>[];
      final seenBarcodes = <String>{};
      final seenKeys = <String>{};
      int medSeqId = 1;

      for (var row in medsRows.skip(1)) {
        if (row.isEmpty || row[0] == null) continue;

        final rawId = row[0].toString().trim();
        final nameAr = row.length > 1 ? row[1]?.toString().trim() ?? '' : '';
        final nameEn = row.length > 2 ? row[2]?.toString().trim() ?? '' : '';
        final sciAr = row.length > 3 ? row[3]?.toString().trim() ?? '' : '';
        final sciEn = row.length > 4 ? row[4]?.toString().trim() ?? '' : '';
        final compAr = row.length > 5 ? row[5]?.toString().trim() ?? '' : '';
        final suppAr = row.length > 8 ? row[8]?.toString().trim() ?? '' : '';
        final pack = row.length > 10 ? row[10]?.toString().trim() ?? '' : '';
        final unit = row.length > 11 ? row[11]?.toString().trim() ?? 'باكت' : 'باكت';
        final priceStr = row.length > 12 ? row[12]?.toString().trim() ?? '0' : '0';
        final bonusStr = row.length > 13 ? row[13]?.toString().trim() ?? '' : '';
        final useAr = row.length > 14 ? row[14]?.toString().trim() ?? '' : '';
        final catAr = row.length > 16 ? row[16]?.toString().trim() ?? '' : '';

        final tradeName = nameAr.isNotEmpty ? nameAr : nameEn;
        if (tradeName.isEmpty) continue;

        final dedupKey = '${tradeName.toLowerCase()}_$rawId';
        if (seenKeys.contains(dedupKey)) continue;
        seenKeys.add(dedupKey);

        final price = double.tryParse(priceStr) ?? 0.0;
        final combinedSci = sciAr.isNotEmpty ? (sciEn.isNotEmpty ? '$sciAr ($sciEn)' : sciAr) : sciEn;

        int? catId = catAr.isNotEmpty ? categoryNameMap[catAr.toLowerCase()] : null;
        int? compId = compAr.isNotEmpty ? companyNameMap[compAr.toLowerCase()] : null;
        int? suppId = suppAr.isNotEmpty ? supplierNameMap[suppAr.toLowerCase()] : null;

        String barcode = '789${medSeqId.toString().padLeft(8, '0')}';
        if (rawId.isNotEmpty && !seenBarcodes.contains(rawId)) {
          barcode = rawId;
        }
        seenBarcodes.add(barcode);

        medicinesToInsert.add(MedicinesCompanion(
          nameAr: drift.Value(nameAr.isNotEmpty ? nameAr : tradeName),
          nameEn: drift.Value(nameEn.isNotEmpty ? nameEn : tradeName),
          nameScientific: drift.Value(combinedSci.isNotEmpty ? combinedSci : null),
          categoryId: drift.Value(catId),
          companyId: drift.Value(compId),
          supplierId: drift.Value(suppId),
          sku: drift.Value(barcode),
          barcode: drift.Value(barcode),
          unit: drift.Value(unit.isNotEmpty ? unit : 'باكت'),
          medicineType: const drift.Value(1),
          purchasePrice: drift.Value(price > 0 ? (price * 0.8) : 0.0),
          sellingPrice: drift.Value(price),
          qtyPerStrip: const drift.Value(10),
          stripPurchasePrice: drift.Value(price > 0 ? (price * 0.8 / 3) : 0.0),
          stripSellingPrice: drift.Value(price > 0 ? (price / 3) : 0.0),
          qtyPerPack: const drift.Value(1),
          packPurchasePrice: drift.Value(price > 0 ? (price * 0.8) : 0.0),
          packSellingPrice: drift.Value(price),
          reserveField1: drift.Value(useAr.isNotEmpty ? useAr : null), // دواعي الاستعمال والوصفة
          reserveField2: drift.Value(compAr.isNotEmpty ? '$compAr - $pack' : pack), // الشركة والتعبئة
          reserveField3: drift.Value(bonusStr.isNotEmpty && bonusStr != 'لا يوجد' ? bonusStr : null), // البونص
          reorderLevel: const drift.Value(5),
          isActive: const drift.Value(true),
        ));

        medSeqId++;
      }

      // الإدراج السريع على دفعات (1000 دواء بكل دفعة)
      const chunkSize = 1000;
      for (var i = 0; i < medicinesToInsert.length; i += chunkSize) {
        final chunk = medicinesToInsert.sublist(
          i,
          i + chunkSize > medicinesToInsert.length ? medicinesToInsert.length : i + chunkSize,
        );
        await _db.batch((batch) {
          batch.insertAll(_db.medicines, chunk, mode: drift.InsertMode.insertOrIgnore);
        });
      }

      debugPrint('🎉 اكتملت زراعة دليل الأدوية الشامل بنجاح: ${medicinesToInsert.length} دواء.');
    } catch (e, stack) {
      debugPrint('❌ حدث خطأ أثناء زراعة قاعدة البيانات: $e\n$stack');
    }
  }
}
