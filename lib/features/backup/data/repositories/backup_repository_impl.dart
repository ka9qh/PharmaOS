import '../../domain/entities/backup_entity.dart';
import '../../domain/repositories/backup_repository.dart';
import '../datasources/backup_datasource.dart';
import '../../../../core/security/audit_logger.dart';

class BackupRepositoryImpl implements BackupRepository {
  final BackupDataSource dataSource;
  final AuditLogger auditLogger;

  BackupRepositoryImpl({required this.dataSource, required this.auditLogger});

  @override
  Future<List<BackupFileInfo>> listBackups() => dataSource.listBackups();

  @override
  Future<String?> createBackupNow() async {
    final path = await dataSource.createBackupNow();
    await auditLogger.log(
      actionType: 'MANUAL_BACKUP_CREATED',
      tableName: 'backups',
      newValue: path,
    );
    return path;
  }
}
