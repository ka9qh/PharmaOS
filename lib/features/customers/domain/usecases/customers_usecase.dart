import '../entities/customers_entity.dart';
import '../repositories/customers_repository.dart';

class ListCustomersUseCase {
  final CustomersRepository _repo;
  const ListCustomersUseCase(this._repo);
  Future<List<CustomerEntity>> call() => _repo.getAll();
}

class CreateCustomerUseCase {
  final CustomersRepository _repo;
  const CreateCustomerUseCase(this._repo);
  Future<CustomerEntity> call({required String name, String? phone, String? notes}) {
    return _repo.create(name: name, phone: phone, notes: notes);
  }
}

class GetCustomerBalancesUseCase {
  final CustomersRepository _repo;
  const GetCustomerBalancesUseCase(this._repo);
  Future<List<CustomerBalance>> call() => _repo.getCustomerBalances();
}

class RecordCustomerPaymentUseCase {
  final CustomersRepository _repo;
  const RecordCustomerPaymentUseCase(this._repo);
  Future<void> call({
    required int customerId,
    required double amount,
    String? notes,
    int? recordedBy,
  }) {
    return _repo.recordPayment(customerId: customerId, amount: amount, notes: notes, recordedBy: recordedBy);
  }
}

class UpdateCustomerUseCase {
  final CustomersRepository _repo;
  const UpdateCustomerUseCase(this._repo);
  Future<void> call(int id, String newName, String? newPhone, String? newNotes) async {}
}
class ArchiveCustomerUseCase {
  final CustomersRepository _repo;
  const ArchiveCustomerUseCase(this._repo);
  Future<void> call(int id) async {}
}
