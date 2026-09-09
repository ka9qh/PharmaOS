import '../entities/audit_logs_entity.dart';
import '../repositories/audit_logs_repository.dart';

class ListRecentAuditLogsUseCase {
  final AuditLogsRepository _repo;
  const ListRecentAuditLogsUseCase(this._repo);
  Future<List<AuditLogEntryEntity>> call({int limit = 20}) => _repo.listRecent(limit: limit);
}
