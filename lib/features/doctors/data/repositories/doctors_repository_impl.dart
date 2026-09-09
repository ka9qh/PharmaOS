import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/repositories/doctors_repository.dart';

class DoctorsRepositoryImpl implements DoctorsRepository {
  final AppDatabase _db;
  DoctorsRepositoryImpl(this._db);

  @override
  Future<List<DoctorRow>> getAll({String? searchQuery}) async {
    final query = _db.select(_db.doctors);
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where((t) => t.name.like('%$searchQuery%') | t.specialty.like('%$searchQuery%'));
    }
    return await query.get();
  }

  @override
  Future<DoctorRow> getById(int id) async {
    return await (_db.select(_db.doctors)..where((t) => t.id.equals(id))).getSingle();
  }

  @override
  Future<int> add(DoctorsCompanion doctor) async {
    return await _db.into(_db.doctors).insert(doctor);
  }

  @override
  Future<void> update(DoctorRow doctor) async {
    await _db.update(_db.doctors).replace(doctor);
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.doctors)..where((t) => t.id.equals(id))).go();
  }
}
