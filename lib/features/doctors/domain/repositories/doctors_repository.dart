import '../../../../core/database/app_database.dart';

abstract class DoctorsRepository {
  Future<List<DoctorRow>> getAll({String? searchQuery});
  Future<DoctorRow> getById(int id);
  Future<int> add(DoctorsCompanion doctor);
  Future<void> update(DoctorRow doctor);
  Future<void> delete(int id);
}
