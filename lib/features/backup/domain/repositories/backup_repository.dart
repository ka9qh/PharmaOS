import '../entities/backup_entity.dart';

abstract class BackupRepository {
  Future<List<BackupFileInfo>> listBackups();

  /// يُنشئ نسخة احتياطية فورية يدويًا (بالإضافة للنسخ التلقائية عند كل تقرير إغلاق)
  Future<String?> createBackupNow();
}
