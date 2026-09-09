import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/repositories/prescriptions_repository.dart';

final prescriptionsProvider = StateNotifierProvider<PrescriptionsNotifier, AsyncValue<List<PrescriptionRow>>>((ref) {
  return PrescriptionsNotifier(sl<PrescriptionsRepository>());
});

class PrescriptionsNotifier extends StateNotifier<AsyncValue<List<PrescriptionRow>>> {
  final PrescriptionsRepository _repository;

  PrescriptionsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadPrescriptions();
  }

  Future<void> loadPrescriptions({int? customerId, int? doctorId, String? searchQuery}) async {
    state = const AsyncValue.loading();
    try {
      final data = await _repository.getAll(customerId: customerId, doctorId: doctorId, searchQuery: searchQuery);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addPrescription(PrescriptionsCompanion prescription) async {
    try {
      await _repository.add(prescription);
      await loadPrescriptions();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updatePrescription(PrescriptionRow prescription) async {
    try {
      await _repository.update(prescription);
      await loadPrescriptions();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deletePrescription(int id) async {
    try {
      await _repository.delete(id);
      await loadPrescriptions();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
