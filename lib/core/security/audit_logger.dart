// تسجيل كل عملية حساسة في جدول audit_logs (راجع docs/AUDIT_LOG_POLICY.md)
// هذا السجل Append-Only: لا توجد أي دالة update أو delete هنا عن قصد.

import 'package:drift/drift.dart';
import '../database/app_database.dart';

class AuditLogger {
  final AppDatabase _db;

  AuditLogger(this._db);

  Future<void> log({
    required String actionType,
    required String tableName,
    String? recordId,
    String? oldValue,
    String? newValue,
    int? userId,
  }) async {
    await _db.into(_db.auditLogs).insert(
          AuditLogsCompanion.insert(
            actionType: actionType,
            targetTable: tableName,
            recordId: Value(recordId),
            oldValue: Value(oldValue),
            newValue: Value(newValue),
            userId: Value(userId),
          ),
        );
  }
}
