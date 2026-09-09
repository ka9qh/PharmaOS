import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/audit_logs_entity.dart';

class AuditLogsDataSource {
  final AppDatabase _db;
  AuditLogsDataSource(this._db);

  Future<List<AuditLogEntryEntity>> listRecent({int limit = 20}) async {
    final rows = await (_db.select(_db.auditLogs)
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)])
          ..limit(limit))
        .get();

    final users = await _db.select(_db.users).get();
    final userNames = {for (final u in users) u.id: u.fullName};

    return rows
        .map((row) => AuditLogEntryEntity(
              id: row.id,
              actionType: row.actionType,
              tableName: row.targetTable,
              recordId: row.recordId,
              userName: row.userId != null ? userNames[row.userId] : null,
              timestamp: row.timestamp,
            ))
        .toList();
  }
}
