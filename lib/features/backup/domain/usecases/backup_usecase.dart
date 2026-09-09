import '../entities/backup_entity.dart';
import '../repositories/backup_repository.dart';

class ListBackupsUseCase {
  final BackupRepository _repo;
  const ListBackupsUseCase(this._repo);
  Future<List<BackupFileInfo>> call() => _repo.listBackups();
}

class CreateBackupNowUseCase {
  final BackupRepository _repo;
  const CreateBackupNowUseCase(this._repo);
  Future<String?> call() => _repo.createBackupNow();
}
