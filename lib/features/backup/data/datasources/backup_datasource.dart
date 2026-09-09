import '../../../../core/services/backup_service.dart';

class BackupDataSource {
  final BackupService _service;
  BackupDataSource(this._service);

  Future<List<BackupFileInfo>> listBackups() => _service.listBackups();
  Future<String?> createBackupNow() => _service.createBackup();
}
