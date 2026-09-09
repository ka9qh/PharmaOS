import '../../../../core/database/app_database.dart';

abstract class PrescriptionsRepository {
  Future<List<PrescriptionRow>> getAll({int? customerId, int? doctorId, String? searchQuery});
  Future<PrescriptionRow> getById(int id);
  Future<int> add(PrescriptionsCompanion prescription);
  Future<void> update(PrescriptionRow prescription);
  Future<void> delete(int id);
}
