import '../../domain/entities/expenses_entity.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../datasources/expenses_datasource.dart';
import '../../../../core/security/audit_logger.dart';

class ExpensesRepositoryImpl implements ExpensesRepository {
  final ExpensesDataSource dataSource;
  final AuditLogger auditLogger;

  ExpensesRepositoryImpl({
    required this.dataSource,
    required this.auditLogger,
  });

  @override
  Future<ExpenseEntity> create({
    required String category,
    required double amount,
    String? notes,
    int? workerId,
    String? customWorkerName,
    String paymentMethod = 'نقدي',
    int? walletId,
    int? recordedBy,
  }) async {
    final entity = await dataSource.create(
      category: category,
      amount: amount,
      notes: notes,
      workerId: workerId,
      customWorkerName: customWorkerName,
      paymentMethod: paymentMethod,
      walletId: walletId,
      recordedBy: recordedBy,
    );

    await auditLogger.log(
      actionType: 'EXPENSE_RECORDED',
      tableName: 'expenses',
      recordId: entity.id.toString(),
      newValue: 'category=${entity.category}, amount=${entity.amount}, method=$paymentMethod, beneficiary=${entity.workerName}',
    );

    return entity;
  }

  @override
  Future<List<ExpenseEntity>> listAll({String? query}) async {
    final entities = await dataSource.listAll();
    return _filter(entities, query);
  }

  @override
  Future<List<ExpenseEntity>> listToday() async {
    return dataSource.listToday();
  }

  @override
  Future<List<ExpenseEntity>> listByDate(DateTime date, {String? query}) async {
    final entities = await dataSource.listByDate(date);
    return _filter(entities, query);
  }

  @override
  Future<List<ExpenseEntity>> listByYear(int year, {String? query}) async {
    final entities = await dataSource.listByYear(year);
    return _filter(entities, query);
  }

  @override
  Future<List<ExpenseEntity>> listByDateRange(DateTime from, DateTime to, {String? query}) async {
    final entities = await dataSource.listByDateRange(from: from, to: to);
    return _filter(entities, query);
  }

  @override
  Future<double> getTodayTotal() => dataSource.getTodayTotal();

  @override
  Future<List<ExpenseEntity>> listByMonthAndYear(int year, int month, {String? query}) async {
    final entities = await dataSource.listByMonth(year: year, month: month);
    return _filter(entities, query);
  }

  List<ExpenseEntity> _filter(List<ExpenseEntity> entities, String? query) {
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      return entities.where((e) =>
          e.category.toLowerCase().contains(q) ||
          (e.notes != null && e.notes!.toLowerCase().contains(q)) ||
          (e.workerName != null && e.workerName!.toLowerCase().contains(q)) ||
          (e.recorderName != null && e.recorderName!.toLowerCase().contains(q)) ||
          (e.walletName != null && e.walletName!.toLowerCase().contains(q)) ||
          e.paymentMethod.toLowerCase().contains(q)).toList();
    }
    return entities;
  }
}
