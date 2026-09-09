import '../entities/audit_logs_entity.dart';

abstract class AuditLogsRepository {
  Future<List<AuditLogEntryEntity>> listRecent({int limit = 20});
}
