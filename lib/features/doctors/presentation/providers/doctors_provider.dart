import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/repositories/doctors_repository.dart';

final doctorsProvider = StateNotifierProvider<DoctorsNotifier, AsyncValue<List<DoctorRow>>>((ref) {
  return DoctorsNotifier(sl<DoctorsRepository>());
});

class DoctorsNotifier extends StateNotifier<AsyncValue<List<DoctorRow>>> {
  final DoctorsRepository _repository;

  DoctorsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadDoctors();
  }

  Future<void> loadDoctors({String? searchQuery}) async {
    state = const AsyncValue.loading();
    try {
      final doctors = await _repository.getAll(searchQuery: searchQuery);
      state = AsyncValue.data(doctors);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addDoctor(DoctorsCompanion doctor) async {
    try {
      await _repository.add(doctor);
      await loadDoctors();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateDoctor(DoctorRow doctor) async {
    try {
      await _repository.update(doctor);
      await loadDoctors();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteDoctor(int id) async {
    try {
      await _repository.delete(id);
      await loadDoctors();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
