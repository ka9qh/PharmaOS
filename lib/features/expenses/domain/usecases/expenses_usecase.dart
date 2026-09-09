
import '../entities/expenses_entity.dart';
import '../repositories/expenses_repository.dart';

class CreateExpenseUseCase {
  final ExpensesRepository _repo;
  const CreateExpenseUseCase(this._repo);

  Future<ExpenseEntity> call({
    required String category,
    required double amount,
    String? notes,
    int? workerId,
    String? customWorkerName,
    String paymentMethod = 'نقدي',
    int? walletId,
    int? recordedBy,
  }) {
    return _repo.create(
      category: category,
      amount: amount,
      notes: notes,
      workerId: workerId,
      customWorkerName: customWorkerName,
      paymentMethod: paymentMethod,
      walletId: walletId,
      recordedBy: recordedBy,
    );
  }
}

class ListTodayExpensesUseCase {
  final ExpensesRepository _repo;
  const ListTodayExpensesUseCase(this._repo);
  Future<List<ExpenseEntity>> call() => _repo.listToday();
}

class GetTodayExpensesTotalUseCase {
  final ExpensesRepository _repo;
  const GetTodayExpensesTotalUseCase(this._repo);
  Future<double> call() => _repo.getTodayTotal();
}

