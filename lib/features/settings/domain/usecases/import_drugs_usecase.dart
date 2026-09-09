import 'dart:io';
import 'package:csv/csv.dart';
import '../../../../core/di/service_locator.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../companies/domain/repositories/companies_repository.dart';
import '../../../suppliers/domain/repositories/suppliers_repository.dart';

class ImportDrugsResult {
  final int addedCount;
  final int updatedCount;
  final int companiesAdded;
  final int suppliersAdded;
  final String? error;

  ImportDrugsResult({
    this.addedCount = 0,
    this.updatedCount = 0,
    this.companiesAdded = 0,
    this.suppliersAdded = 0,
    this.error,
  });
}

class ImportDrugsUseCase {
  final MedicinesRepository _medicinesRepo;
  final CompaniesRepository _companiesRepo;
  final SuppliersRepository _suppliersRepo;

  ImportDrugsUseCase(
    this._medicinesRepo,
    this._companiesRepo,
    this._suppliersRepo,
  );

  Future<ImportDrugsResult> call(String directoryPath) async {
    try {
      final drugsFile = File('$directoryPath\\Drugs_all.csv');
      final scientificFile = File('$directoryPath\\Scientific_all.csv');
      final companiesFile = File('$directoryPath\\Companies_all.csv');
      final proxiesFile = File('$directoryPath\\Proxies_all.csv');

      if (!drugsFile.existsSync() ||
          !scientificFile.existsSync() ||
          !companiesFile.existsSync() ||
          !proxiesFile.existsSync()) {
        return ImportDrugsResult(error: 'بعض ملفات CSV مفقودة في المسار المحدد (Drugs_all, Scientific_all, Companies_all, Proxies_all)');
      }

      final drugsData = const CsvToListConverter().convert(await drugsFile.readAsString());
      final scientificData = const CsvToListConverter().convert(await scientificFile.readAsString());
      final companiesData = const CsvToListConverter().convert(await companiesFile.readAsString());
      final proxiesData = const CsvToListConverter().convert(await proxiesFile.readAsString());

      int addedCount = 0;
      int updatedCount = 0;
      int companiesAdded = 0;
      int suppliersAdded = 0;

      // 1. معالجة الشركات (Companies)
      final existingCompanies = await _companiesRepo.getAll();
      final Map<String, int> companyIdMap = {}; // Maps CSV ID to DB ID
      
      for (var row in companiesData.skip(1)) {
        if (row.isEmpty || row[0] == null) continue;
        final csvId = row[0].toString();
        final nameEn = row[1]?.toString() ?? '';
        final nameAr = row[2]?.toString() ?? '';
        final finalName = nameAr.isNotEmpty ? nameAr : nameEn;

        if (finalName.isEmpty) continue;

        // البحث إن كانت الشركة موجودة مسبقاً في النظام
        final existing = existingCompanies.where((c) => c.name == finalName).firstOrNull;
        if (existing != null) {
          companyIdMap[csvId] = existing.id;
        } else {
          final newCompany = await _companiesRepo.create(finalName);
          companyIdMap[csvId] = newCompany.id;
          existingCompanies.add(newCompany); // لتفادي التكرار إذا تكرر الاسم
          companiesAdded++;
        }
      }

      // 2. معالجة الوكلاء (Proxies / Suppliers)
      final existingSuppliers = await _suppliersRepo.getAll();
      final Map<String, int> supplierIdMap = {};

      for (var row in proxiesData.skip(1)) {
        if (row.isEmpty || row[0] == null) continue;
        final csvId = row[0].toString();
        final nameEn = row[1]?.toString() ?? '';
        final nameAr = row[2]?.toString() ?? '';
        final finalName = nameAr.isNotEmpty ? nameAr : nameEn;

        if (finalName.isEmpty) continue;

        final existing = existingSuppliers.where((s) => s.name == finalName).firstOrNull;
        if (existing != null) {
          supplierIdMap[csvId] = existing.id;
        } else {
          final newSupplier = await _suppliersRepo.create(name: finalName);
          supplierIdMap[csvId] = newSupplier.id;
          existingSuppliers.add(newSupplier);
          suppliersAdded++;
        }
      }

      // 3. معالجة الأسماء العلمية ودواعي الاستعمال
      final scientificMap = {
        for (var row in scientificData.skip(1)) row[0].toString(): {
          'scientificName_en': row[1]?.toString() ?? '',
          'scientificName_ar': row[2]?.toString() ?? '',
          'theUse_en': row[3]?.toString() ?? '',
          'theUse_ar': row[4]?.toString() ?? '',
        }
      };

      // 4. معالجة الأدوية
      final allMedicines = await _medicinesRepo.getAll();

      for (var row in drugsData.skip(1)) {
        if (row.isEmpty || row[0] == null) continue;

        final String barcode = row[0].toString();
        final String drugNameEn = row[1]?.toString() ?? '';
        final String drugNameAr = row[2]?.toString() ?? '';
        final double price = double.tryParse(row[3]?.toString() ?? '0') ?? 0.0;
        final String unit = row[4]?.toString() ?? '';
        
        final String scienId = row[5]?.toString() ?? '';
        final String compId = row[6]?.toString() ?? '';
        final String proxyId = row[7]?.toString() ?? '';

        final scienData = scientificMap[scienId];
        final String scientificName = scienData?['scientificName_ar'] ?? scienData?['scientificName_en'] ?? '';
        final String medicalUse = scienData?['theUse_ar'] ?? scienData?['theUse_en'] ?? '';
        
        final int? dbCompanyId = companyIdMap[compId];
        final int? dbSupplierId = supplierIdMap[proxyId];

        final String fullDescription = '''
دواعي الاستعمال: $medicalUse
الوحدة والتعبئة: $unit
        '''.trim();

        // فحص وجود الدواء (بالباركود أو الاسم)
        final existingDrug = allMedicines.where((m) => m.barcode == barcode || m.nameAr == drugNameAr).firstOrNull;

        if (existingDrug != null) {
          // تحديث
          final updated = existingDrug.copyWith(
            nameAr: drugNameAr.isNotEmpty ? drugNameAr : existingDrug.nameAr,
            nameEn: drugNameEn.isNotEmpty ? drugNameEn : existingDrug.nameEn,
            nameScientific: scientificName.isNotEmpty ? scientificName : existingDrug.nameScientific,
            companyId: dbCompanyId ?? existingDrug.companyId,
            supplierId: dbSupplierId ?? existingDrug.supplierId,
            sellingPrice: price > 0 ? price : existingDrug.sellingPrice,
            reserveField1: fullDescription.isNotEmpty ? fullDescription : existingDrug.reserveField1,
          );
          await _medicinesRepo.update(updated);
          updatedCount++;
        } else {
          // إضافة جديد
          await _medicinesRepo.create(
            nameAr: drugNameAr.isNotEmpty ? drugNameAr : drugNameEn,
            nameEn: drugNameEn,
            nameScientific: scientificName,
            companyId: dbCompanyId,
            supplierId: dbSupplierId,
            unit: 'حبة', // الوحدة الافتراضية
            purchasePrice: price * 0.8, // سعر شراء افتراضي
            sellingPrice: price,
            reserveField1: fullDescription,
            barcode: barcode,
            reorderLevel: 10,
          );
          addedCount++;
        }
      }

      return ImportDrugsResult(
        addedCount: addedCount,
        updatedCount: updatedCount,
        companiesAdded: companiesAdded,
        suppliersAdded: suppliersAdded,
      );
    } catch (e) {
      return ImportDrugsResult(error: e.toString());
    }
  }
}
