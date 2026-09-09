import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/audit_logger.dart';
import '../../../accounting/domain/repositories/general_ledger_repository.dart';
import '../../../accounting/domain/entities/accounting_entities.dart';
import '../../domain/entities/payroll_entities.dart';
import '../../domain/repositories/payroll_repository.dart';

class PayrollRepositoryImpl implements PayrollRepository {
  final AppDatabase _db;
  final AuditLogger _auditLogger;
  final GeneralLedgerRepository _glRepo;

  PayrollRepositoryImpl(this._db, this._auditLogger, this._glRepo);

  Future<PayrollEntity> _mapPayrollRow(PayrollRow r) async {
    final worker = await (_db.select(_db.workers)..where((w) => w.id.equals(r.workerId))).getSingle();
    return PayrollEntity(
      id: r.id,
      workerId: r.workerId,
      workerName: worker.name,
      month: r.month,
      year: r.year,
      baseSalary: r.baseSalary,
      totalAllowances: r.totalAllowances,
      totalDeductions: r.totalDeductions,
      totalAdvancesDeducted: r.totalAdvancesDeducted,
      daysWorked: r.daysWorked,
      daysAbsent: r.daysAbsent,
      netSalary: r.netSalary,
      paymentMethod: r.paymentMethod,
      status: r.status,
      paidBy: r.paidBy,
      paidAt: r.paidAt,
      notes: r.notes,
      createdAt: r.createdAt,
    );
  }

  @override
  Future<PayrollEntity> generatePayroll({
    required int workerId,
    required int month,
    required int year,
    String? notes,
  }) async {
    final worker = await (_db.select(_db.workers)..where((w) => w.id.equals(workerId))).getSingle();

    // حساب أيام العمل والغياب من جدول الحضور
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);
    
    final attendanceRows = await (_db.select(_db.workerAttendance)
          ..where((a) =>
              a.workerId.equals(workerId) &
              a.attendanceDate.isBiggerOrEqualValue(startOfMonth) &
              a.attendanceDate.isSmallerOrEqualValue(endOfMonth)))
        .get();
    
    final daysAttended = attendanceRows.where((a) => a.isAttended).length.toDouble();
    final daysAbsent = attendanceRows.where((a) => !a.isAttended).length.toDouble();

    // حساب البدلات
    double totalAllowances = 0;
    if (!worker.allowanceIsDeducted && worker.dailyAllowance > 0) {
      totalAllowances = worker.dailyAllowance * daysAttended;
    }

    // حساب خصم الغياب (إذا كان المصروف يُخصم من الراتب)
    double absenceDeduction = 0;
    if (daysAbsent > 0 && worker.salary > 0) {
      final dailySalary = worker.salary / 30; // تقريب 30 يوم
      absenceDeduction = dailySalary * daysAbsent;
    }

    // حساب السلف المتبقية لخصمها
    final remainingAdvances = await getTotalRemainingAdvances(workerId);
    // نخصم من السلف بحد أقصى المتبقي من الراتب بعد خصومات الغياب
    final maxDeductible = worker.salary - absenceDeduction;
    final advanceDeduction = remainingAdvances > maxDeductible * 0.5
        ? maxDeductible * 0.5 // لا نخصم أكثر من 50% من الراتب كسلف
        : remainingAdvances;

    final totalDeductions = absenceDeduction + advanceDeduction;
    final netSalary = worker.salary + totalAllowances - totalDeductions;

    final id = await _db.into(_db.payroll).insert(
      PayrollCompanion.insert(
        workerId: workerId,
        month: month,
        year: year,
        baseSalary: worker.salary,
        totalAllowances: Value(totalAllowances),
        totalDeductions: Value(totalDeductions),
        totalAdvancesDeducted: Value(advanceDeduction),
        daysWorked: Value(daysAttended),
        daysAbsent: Value(daysAbsent),
        netSalary: netSalary,
        notes: Value(notes),
      ),
    );

    await _auditLogger.log(
      actionType: 'PAYROLL_GENERATED',
      tableName: 'payroll',
      recordId: id.toString(),
      newValue: 'worker=${worker.name}, net=$netSalary, month=$month/$year',
    );

    final row = await (_db.select(_db.payroll)..where((p) => p.id.equals(id))).getSingle();
    return _mapPayrollRow(row);
  }

  @override
  Future<void> payPayroll({
    required int payrollId,
    required String paymentMethod,
    required int paidBy,
  }) async {
    return _db.transaction(() async {
      final row = await (_db.select(_db.payroll)..where((p) => p.id.equals(payrollId))).getSingle();
      if (row.status == 'paid') throw Exception('هذا الراتب مصروف مسبقاً');

      // تحديث حالة الكشف
      await (_db.update(_db.payroll)..where((p) => p.id.equals(payrollId))).write(
        PayrollCompanion(
          status: const Value('paid'),
          paymentMethod: Value(paymentMethod),
          paidBy: Value(paidBy),
          paidAt: Value(DateTime.now()),
        ),
      );

      // خصم السلف فعلياً
      if (row.totalAdvancesDeducted > 0) {
        var remaining = row.totalAdvancesDeducted;
        final advances = await (_db.select(_db.workerAdvances)
              ..where((a) => a.workerId.equals(row.workerId) & a.isFullyDeducted.equals(false))
              ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
            .get();
        
        for (final adv in advances) {
          if (remaining <= 0) break;
          final deduct = adv.remainingAmount > remaining ? remaining : adv.remainingAmount;
          final newRemaining = adv.remainingAmount - deduct;
          await (_db.update(_db.workerAdvances)..where((a) => a.id.equals(adv.id))).write(
            WorkerAdvancesCompanion(
              remainingAmount: Value(newRemaining),
              isFullyDeducted: Value(newRemaining <= 0),
            ),
          );
          remaining -= deduct;
        }
      }

      // القيد المحاسبي: حـ/ الرواتب والأجور (مدين) ⬅️ حـ/ الصندوق (دائن)
      try {
        final salaryExpAccId = await _glRepo.getAccountIdByCode('5101'); // مصروف الرواتب
        final cashAccId = await _glRepo.getAccountIdByCode('1101'); // الصندوق

        if (salaryExpAccId == null) {
          // إنشاء حساب مصروف الرواتب إذا لم يوجد
          await _glRepo.addAccount(
            code: '5101',
            name: 'الرواتب والأجور',
            type: 'expense',
            isHeader: false,
          );
        }
        
        final worker = await (_db.select(_db.workers)..where((w) => w.id.equals(row.workerId))).getSingle();
        
        final expAccId = salaryExpAccId ?? await _glRepo.getAccountIdByCode('5101');
        if (expAccId != null && cashAccId != null) {
          await _glRepo.postJournalEntry(
            referenceNumber: 'JE-SAL-${row.year}${row.month.toString().padLeft(2, '0')}-${row.workerId}',
            date: DateTime.now(),
            description: 'صرف راتب ${worker.name} - شهر ${row.month}/${row.year}',
            source: 'Payroll',
            sourceId: payrollId,
            createdBy: paidBy,
            lines: [
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0,
                accountId: expAccId, accountName: '',
                debit: row.netSalary, credit: 0,
                description: 'مصروف راتب ${worker.name}',
              ),
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0,
                accountId: cashAccId, accountName: '',
                debit: 0, credit: row.netSalary,
                description: 'صرف راتب ${worker.name} من الصندوق',
              ),
            ],
          );
        }
      } catch (e) {
        print('فشل تسجيل القيد المحاسبي للرواتب: $e');
      }

      await _auditLogger.log(
        actionType: 'PAYROLL_PAID',
        tableName: 'payroll',
        recordId: payrollId.toString(),
        userId: paidBy,
        newValue: 'net=${row.netSalary}',
      );
    });
  }

  @override
  Future<List<PayrollEntity>> getPayrollForMonth(int month, int year) async {
    final rows = await (_db.select(_db.payroll)
          ..where((p) => p.month.equals(month) & p.year.equals(year))
          ..orderBy([(p) => OrderingTerm.asc(p.workerId)]))
        .get();
    return Future.wait(rows.map(_mapPayrollRow));
  }

  @override
  Future<List<PayrollEntity>> getPayrollForWorker(int workerId) async {
    final rows = await (_db.select(_db.payroll)
          ..where((p) => p.workerId.equals(workerId))
          ..orderBy([(p) => OrderingTerm.desc(p.year), (p) => OrderingTerm.desc(p.month)]))
        .get();
    return Future.wait(rows.map(_mapPayrollRow));
  }

  // ========== السلف ==========

  Future<WorkerAdvanceEntity> _mapAdvanceRow(WorkerAdvanceRow r) async {
    final worker = await (_db.select(_db.workers)..where((w) => w.id.equals(r.workerId))).getSingle();
    return WorkerAdvanceEntity(
      id: r.id,
      workerId: r.workerId,
      workerName: worker.name,
      amount: r.amount,
      reason: r.reason,
      isFullyDeducted: r.isFullyDeducted,
      remainingAmount: r.remainingAmount,
      paymentMethod: r.paymentMethod,
      approvedBy: r.approvedBy,
      notes: r.notes,
      createdAt: r.createdAt,
    );
  }

  @override
  Future<WorkerAdvanceEntity> createAdvance({
    required int workerId,
    required double amount,
    String? reason,
    String paymentMethod = 'نقدي',
    int? approvedBy,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw Exception('لا يمكن تسجيل سلفة بقيمة سالبة أو صفر');
    }

    return _db.transaction(() async {
      final id = await _db.into(_db.workerAdvances).insert(
        WorkerAdvancesCompanion.insert(
          workerId: workerId,
          amount: amount,
          remainingAmount: amount,
          reason: Value(reason),
          paymentMethod: Value(paymentMethod),
          approvedBy: Value(approvedBy),
          notes: Value(notes),
        ),
      );

      // القيد المحاسبي: حـ/ سلف الموظفين (مدين) ⬅️ حـ/ الصندوق (دائن)
      try {
        var advAccId = await _glRepo.getAccountIdByCode('1201'); // ذمم مدينة - سلف
        if (advAccId == null) {
          await _glRepo.addAccount(code: '1201', name: 'سلف الموظفين', type: 'asset');
          advAccId = await _glRepo.getAccountIdByCode('1201');
        }
        final cashAccId = await _glRepo.getAccountIdByCode('1101');
        
        final worker = await (_db.select(_db.workers)..where((w) => w.id.equals(workerId))).getSingle();
        
        if (advAccId != null && cashAccId != null) {
          await _glRepo.postJournalEntry(
            referenceNumber: 'JE-ADV-$id',
            date: DateTime.now(),
            description: 'سلفة لـ ${worker.name} بمبلغ $amount',
            source: 'WorkerAdvance',
            sourceId: id,
            createdBy: approvedBy,
            lines: [
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0,
                accountId: advAccId, accountName: '',
                debit: amount, credit: 0,
                description: 'سلفة ${worker.name}',
              ),
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0,
                accountId: cashAccId, accountName: '',
                debit: 0, credit: amount,
                description: 'صرف سلفة ${worker.name} من الصندوق',
              ),
            ],
          );
        }
      } catch (e) {
        print('فشل تسجيل القيد المحاسبي للسلفة: $e');
      }

      await _auditLogger.log(
        actionType: 'WORKER_ADVANCE_CREATED',
        tableName: 'worker_advances',
        recordId: id.toString(),
        userId: approvedBy,
        newValue: 'worker=$workerId, amount=$amount',
      );

      final row = await (_db.select(_db.workerAdvances)..where((a) => a.id.equals(id))).getSingle();
      return _mapAdvanceRow(row);
    });
  }

  @override
  Future<List<WorkerAdvanceEntity>> getAllAdvances() async {
    final rows = await (_db.select(_db.workerAdvances)..orderBy([(a) => OrderingTerm.desc(a.createdAt)])).get();
    return Future.wait(rows.map(_mapAdvanceRow));
  }

  @override
  Future<List<WorkerAdvanceEntity>> getActiveAdvancesForWorker(int workerId) async {
    final rows = await (_db.select(_db.workerAdvances)
          ..where((a) => a.workerId.equals(workerId) & a.isFullyDeducted.equals(false))
          ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
        .get();
    return Future.wait(rows.map(_mapAdvanceRow));
  }

  @override
  Future<double> getTotalRemainingAdvances(int workerId) async {
    final rows = await (_db.select(_db.workerAdvances)
          ..where((a) => a.workerId.equals(workerId) & a.isFullyDeducted.equals(false)))
        .get();
    return rows.fold<double>(0.0, (sum, a) => sum + a.remainingAmount);
  }
}
