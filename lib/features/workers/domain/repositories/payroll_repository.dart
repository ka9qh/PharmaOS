import '../entities/payroll_entities.dart';

abstract class PayrollRepository {
  /// توليد كشف الراتب لموظف معين لشهر معين
  /// يحسب تلقائياً: أيام العمل/الغياب، البدلات، خصم السلف
  Future<PayrollEntity> generatePayroll({
    required int workerId,
    required int month,
    required int year,
    String? notes,
  });

  /// صرف الراتب فعلياً + توليد قيد محاسبي
  Future<void> payPayroll({
    required int payrollId,
    required String paymentMethod,
    required int paidBy,
  });

  /// جلب كشوف رواتب شهر معين
  Future<List<PayrollEntity>> getPayrollForMonth(int month, int year);

  /// جلب كشوف رواتب موظف معين
  Future<List<PayrollEntity>> getPayrollForWorker(int workerId);

  // ========== السلف ==========
  
  /// تسجيل سلفة جديدة + قيد محاسبي
  Future<WorkerAdvanceEntity> createAdvance({
    required int workerId,
    required double amount,
    String? reason,
    String paymentMethod = 'نقدي',
    int? approvedBy,
    String? notes,
  });

  /// جلب جميع السلف
  Future<List<WorkerAdvanceEntity>> getAllAdvances();

  /// جلب السلف النشطة (غير المسددة بالكامل) لموظف
  Future<List<WorkerAdvanceEntity>> getActiveAdvancesForWorker(int workerId);

  /// إجمالي السلف المتبقية لموظف
  Future<double> getTotalRemainingAdvances(int workerId);
}
