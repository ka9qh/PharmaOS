import '../entities/medicines_entity.dart';
import '../repositories/medicines_repository.dart';

class ListMedicinesUseCase {
  final MedicinesRepository _repo;
  const ListMedicinesUseCase(this._repo);
  Future<List<MedicineEntity>> call({String? searchQuery}) =>
      _repo.getAll(searchQuery: searchQuery);
}

class FindMedicineByBarcodeUseCase {
  final MedicinesRepository _repo;
  const FindMedicineByBarcodeUseCase(this._repo);
  Future<MedicineEntity?> call(String barcode) => _repo.getByBarcode(barcode);
}

class CreateMedicineUseCase {
  final MedicinesRepository _repo;
  const CreateMedicineUseCase(this._repo);

  Future<MedicineEntity> call({
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
    String? reserveField1,
    String? reserveField2,
    String? reserveField3,
    int? medicineType,
  }) {
    return _repo.create(
      nameAr: nameAr,
      nameEn: nameEn,
      nameScientific: nameScientific,
      categoryId: categoryId,
      companyId: companyId,
      supplierId: supplierId,
      unit: unit,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      qtyPerPack: qtyPerPack,
      qtyPerStrip: qtyPerStrip,
      qtyPerCarton: qtyPerCarton,
      stripPurchasePrice: stripPurchasePrice,
      stripSellingPrice: stripSellingPrice,
      packPurchasePrice: packPurchasePrice,
      packSellingPrice: packSellingPrice,
      cartonPurchasePrice: cartonPurchasePrice,
      cartonSellingPrice: cartonSellingPrice,
      reorderLevel: reorderLevel,
      reserveField1: reserveField1,
      reserveField2: reserveField2,
      reserveField3: reserveField3,
      medicineType: medicineType,
    );
  }
}

class UpdateMedicineUseCase {
  final MedicinesRepository _repo;
  const UpdateMedicineUseCase(this._repo);
  Future<void> call(MedicineEntity medicine, {int? changedByUserId}) =>
      _repo.update(medicine, changedByUserId: changedByUserId);
}

class AutoCleanDuplicatesUseCase {
  final MedicinesRepository _repo;
  const AutoCleanDuplicatesUseCase(this._repo);
  Future<int> call() => _repo.autoCleanDuplicates();
}
