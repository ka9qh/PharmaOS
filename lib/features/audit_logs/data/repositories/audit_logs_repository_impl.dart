import '../../domain/entities/audit_logs_entity.dart';
import '../../domain/repositories/audit_logs_repository.dart';
import '../datasources/audit_logs_datasource.dart';

class AuditLogsRepositoryImpl implements AuditLogsRepository {
  final AuditLogsDataSource dataSource;
  AuditLogsRepositoryImpl(this.dataSource);

  @override
  Future<List<AuditLogEntryEntity>> listRecent({int limit = 20}) =>
      dataSource.listRecent(limit: limit);
}
