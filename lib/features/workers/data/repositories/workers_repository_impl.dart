import '../../domain/entities/workers_entity.dart';
import '../../domain/repositories/workers_repository.dart';
import '../datasources/workers_datasource.dart';

class WorkersRepositoryImpl implements WorkersRepository {
  final WorkersDataSource dataSource;
  WorkersRepositoryImpl(this.dataSource);

  @override
  Future<List<WorkerEntity>> getAllWorkers() => dataSource.getAllWorkers();

  @override
  Future<WorkerEntity> createWorker({
    required String name,
    String? phone,
    required double salary,
    double? dailyWithdrawalLimit,
    required bool allowanceIsDeducted,
    String? notes,
  }) {
    return dataSource.createWorker(
      name: name,
      phone: phone,
      salary: salary,
      dailyWithdrawalLimit: dailyWithdrawalLimit,
      allowanceIsDeducted: allowanceIsDeducted,
      notes: notes,
    );
  }

  @override
  Future<void> updateWorker({
    required int id,
    required String name,
    String? phone,
    required double salary,
    double? dailyWithdrawalLimit,
    required bool allowanceIsDeducted,
    String? notes,
  }) {
    return dataSource.updateWorker(
      id: id,
      name: name,
      phone: phone,
      salary: salary,
      dailyWithdrawalLimit: dailyWithdrawalLimit,
      allowanceIsDeducted: allowanceIsDeducted,
      notes: notes,
    );
  }

  @override
  Future<void> archiveWorker(int id) => dataSource.archiveWorker(id);
}
