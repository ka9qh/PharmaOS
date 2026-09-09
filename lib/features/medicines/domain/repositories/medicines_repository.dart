import '../entities/medicines_entity.dart';

abstract class MedicinesRepository {
  Future<List<MedicineEntity>> getAll({String? searchQuery});
  Future<MedicineEntity?> getById(int id);
  Future<MedicineEntity?> getByBarcode(String barcode);
  
  /// جلب البدائل الطبية لدواء معين (بناءً على التركيبة / الاسم العلمي)
  Future<List<MedicineEntity>> getAlternatives(int medicineId, String scientificName);

  Future<MedicineEntity> create({
    required String nameAr,
    String? nameEn,
    String? nameScientific,
    int? categoryId,
    int? companyId,
    int? supplierId,
    required String unit,
    required double purchasePrice,
    required double sellingPrice,
    int? qtyPerPack,
    int? qtyPerStrip,
    int? qtyPerCarton,
    double? stripPurchasePrice,
    double? stripSellingPrice,
    double? packPurchasePrice,
    double? packSellingPrice,
    double? cartonPurchasePrice,
    double? cartonSellingPrice,
    required int reorderLevel,
    String? barcode, // باركود حقيقي (استيراد Excel) - إن غاب، يُولَّد تلقائيًا
    String? reserveField1,
    String? reserveField2,
    String? reserveField3,
    int? medicineType,
  });

  Future<void> update(MedicineEntity medicine, {int? changedByUserId});
  Future<bool> updateBarcode(int medicineId, String newBarcode, {bool forceOverride = false});
  Future<void> archive(int id, {int? changedByUserId});
  Future<void> writeOff(int id, double quantity, String reason, String? notes);
  Future<int> autoCleanDuplicates();
}
