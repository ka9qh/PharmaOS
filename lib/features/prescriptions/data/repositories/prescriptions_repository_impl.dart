import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/repositories/prescriptions_repository.dart';

class PrescriptionsRepositoryImpl implements PrescriptionsRepository {
  final AppDatabase _db;
  PrescriptionsRepositoryImpl(this._db);

  @override
  Future<List<PrescriptionRow>> getAll({int? customerId, int? doctorId, String? searchQuery}) async {
    final query = _db.select(_db.prescriptions);
    if (customerId != null) {
      query.where((t) => t.customerId.equals(customerId));
    }
    if (doctorId != null) {
      query.where((t) => t.doctorId.equals(doctorId));
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where((t) => t.prescriptionNumber.like('%$searchQuery%') | t.diagnosis.like('%$searchQuery%'));
    }
    return await query.get();
  }

  @override
  Future<PrescriptionRow> getById(int id) async {
    return await (_db.select(_db.prescriptions)..where((t) => t.id.equals(id))).getSingle();
  }

  @override
  Future<int> add(PrescriptionsCompanion prescription) async {
    return await _db.into(_db.prescriptions).insert(prescription);
  }

  @override
  Future<void> update(PrescriptionRow prescription) async {
    await _db.update(_db.prescriptions).replace(prescription);
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.prescriptions)..where((t) => t.id.equals(id))).go();
  }
}
