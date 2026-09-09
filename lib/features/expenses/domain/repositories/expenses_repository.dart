import '../entities/expenses_entity.dart';

abstract class ExpensesRepository {
  Future<ExpenseEntity> create({
    required String category,
    required double amount,
    String? notes,
    int? workerId,
    String? customWorkerName,
    String paymentMethod = 'نقدي',
    int? walletId,
    int? recordedBy,
  });

  Future<List<ExpenseEntity>> listAll({String? query});
  Future<List<ExpenseEntity>> listToday();
  Future<List<ExpenseEntity>> listByDate(DateTime date, {String? query});
  Future<List<ExpenseEntity>> listByMonthAndYear(int year, int month, {String? query});
  Future<List<ExpenseEntity>> listByYear(int year, {String? query});
  Future<List<ExpenseEntity>> listByDateRange(DateTime from, DateTime to, {String? query});
  Future<double> getTodayTotal();
}
