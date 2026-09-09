import '../../domain/entities/reports_entity.dart';
import '../../domain/repositories/reports_repository.dart';
import '../datasources/reports_datasource.dart';
import '../models/reports_model.dart';
import '../../../../core/security/audit_logger.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  final ReportsDataSource dataSource;
  final AuditLogger auditLogger;

  ReportsRepositoryImpl({required this.dataSource, required this.auditLogger});

  @override
  Future<DayClosingSummary> previewCurrentPeriod() => dataSource.previewCurrentPeriod();

  @override
  Future<DateTime?> getLastClosingTime() => dataSource.getLastClosingTime();

  @override
  Future<DayClosingResult> closeCurrentPeriod({int? closedByUserId}) async {
    final result = await dataSource.closeCurrentPeriod(closedByUserId: closedByUserId);
    await auditLogger.log(
      actionType: 'PERIOD_CLOSED',
      tableName: 'day_closings',
      recordId: result.summary.periodEnd.toIso8601String(),
      userId: closedByUserId,
      newValue: 'netProfit=${result.summary.netProfit}',
    );
    return result;
  }

  @override
  Future<List<DayClosingRecordEntity>> listRecent({int limit = 30}) async {
    final rows = await dataSource.listRecent(limit: limit);
    return rows.map((r) => r.toEntity()).toList();
  }

  @override
  Future<void> deleteClosingRecord(int id, {int? deletedBy}) async {
    await dataSource.deleteClosingRecord(id);
    await auditLogger.log(
      actionType: 'CLOSING_RECORD_DELETED',
      tableName: 'day_closings',
      recordId: id.toString(),
      userId: deletedBy,
    );
  }
}
