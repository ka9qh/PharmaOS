import '../entities/workers_entity.dart';

abstract class WorkersRepository {
  Future<List<WorkerEntity>> getAllWorkers();
  Future<WorkerEntity> createWorker({
    required String name,
    String? phone,
    required double salary,
    double? dailyWithdrawalLimit,
    required bool allowanceIsDeducted,
    String? notes,
  });
  Future<void> updateWorker({
    required int id,
    required String name,
    String? phone,
    required double salary,
    double? dailyWithdrawalLimit,
    required bool allowanceIsDeducted,
    String? notes,
  });
  Future<void> archiveWorker(int id);
}
