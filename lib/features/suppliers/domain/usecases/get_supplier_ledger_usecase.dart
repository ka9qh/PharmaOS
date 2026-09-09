import '../../../../core/entities/ledger_entry_entity.dart';
import '../../data/datasources/supplier_ledger_datasource.dart';

class GetSupplierLedgerUseCase {
  final SupplierLedgerDataSource _dataSource;

  GetSupplierLedgerUseCase(this._dataSource);

  Future<List<LedgerEntryEntity>> call(int supplierId, {DateTime? startDate, DateTime? endDate}) {
    return _dataSource.getSupplierLedger(supplierId, startDate: startDate, endDate: endDate);
  }
}
