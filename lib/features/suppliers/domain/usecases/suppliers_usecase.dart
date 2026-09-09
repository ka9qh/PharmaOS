import '../entities/suppliers_entity.dart';
import '../repositories/suppliers_repository.dart';
import '../../../purchases/domain/entities/purchases_entity.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';

class ListSuppliersUseCase {
  final SuppliersRepository _repo;
  const ListSuppliersUseCase(this._repo);
  Future<List<SupplierEntity>> call() => _repo.getAll();
}

class CreateSupplierUseCase {
  final SuppliersRepository _repo;
  const CreateSupplierUseCase(this._repo);
  Future<SupplierEntity> call({
    required String name,
    String? contactInfo,
    String? notes,
  }) {
    return _repo.create(name: name, contactInfo: contactInfo, notes: notes);
  }
}

class UpdateSupplierUseCase {
  final SuppliersRepository _repo;
  const UpdateSupplierUseCase(this._repo);
  Future<void> call(int id, String newName) => _repo.update(id, newName);
}

class ArchiveSupplierUseCase {
  final SuppliersRepository _repo;
  const ArchiveSupplierUseCase(this._repo);
  Future<void> call(int id) => _repo.archive(id);
}



class GetSupplierPurchasesUseCase {
  final SuppliersRepository _repo;
  const GetSupplierPurchasesUseCase(this._repo);
  Future<List<PurchaseEntity>> call(int supplierId) => _repo.getSupplierPurchases(supplierId);
}

class GetSupplierMedicinesUseCase {
  final SuppliersRepository _repo;
  const GetSupplierMedicinesUseCase(this._repo);
  Future<List<MedicineEntity>> call(int supplierId) => _repo.getSupplierMedicines(supplierId);
}
