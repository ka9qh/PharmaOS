import '../entities/suppliers_entity.dart';
import '../../../purchases/domain/entities/purchases_entity.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
abstract class SuppliersRepository {
  Future<List<SupplierEntity>> getAll();
  Future<SupplierEntity> create({
    required String name,
    String? contactInfo,
    String? notes,
  });
  Future<void> update(int id, String newName);
  Future<void> archive(int id);
  Future<List<dynamic>> getPharmacyDebts();
  Future<void> recordVendorPayment({
    required int supplierId,
    required double amount,
    required String paymentMethod,
    String? notes,
  });
  Future<List<PurchaseEntity>> getSupplierPurchases(int supplierId);
  Future<List<MedicineEntity>> getSupplierMedicines(int supplierId);
}
