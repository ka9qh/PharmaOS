import '../../../../core/entities/ledger_entry_entity.dart';
import '../../data/datasources/customer_ledger_datasource.dart';

class GetCustomerLedgerUseCase {
  final CustomerLedgerDataSource _dataSource;

  GetCustomerLedgerUseCase(this._dataSource);

  Future<List<LedgerEntryEntity>> call(int customerId, {DateTime? startDate, DateTime? endDate}) {
    return _dataSource.getCustomerLedger(customerId, startDate: startDate, endDate: endDate);
  }
}
