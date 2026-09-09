import '../../domain/entities/cash_register_entity.dart';
import '../../domain/repositories/cash_register_repository.dart';
import '../datasources/cash_register_datasource.dart';

class CashRegisterRepositoryImpl implements CashRegisterRepository {
  final CashRegisterDataSource _dataSource;

  CashRegisterRepositoryImpl(this._dataSource);

  @override
  Future<List<WalletEntity>> getWallets() async {
    final wallets = await _dataSource.getWallets();
    final result = <WalletEntity>[];
    for (var w in wallets) {
      final txs = await _dataSource.getTransactions(walletId: w.id);
      final balance = _calculateBalance(txs);
      result.add(WalletEntity(
        id: w.id,
        name: w.name,
        balance: balance,
      ));
    }
    return result;
  }

  @override
  Future<void> addWallet(String name) async {
    await _dataSource.addWallet(name);
  }

  @override
  Future<void> deleteWallet(int id) async {
    await _dataSource.deleteWallet(id);
  }

  @override
  Future<double> getCashBalance() async {
    final txs = await _dataSource.getTransactions(walletId: null);
    return _calculateBalance(txs);
  }

  @override
  Future<List<TransactionEntity>> getTransactions({int? walletId}) async {
    final txs = await _dataSource.getTransactions(walletId: walletId);
    return txs
        .map((t) => TransactionEntity(
              id: t.id,
              description: t.description,
              amount: t.amount,
              date: t.date,
              type: t.type,
              source: t.source,
            ))
        .toList();
  }

  double _calculateBalance(List<TransactionData> txs) {
    double bal = 0;
    for (var t in txs) {
      if (t.type == 'IN') {
        bal += t.amount;
      } else if (t.type == 'OUT') {
        bal -= t.amount;
      }
    }
    return bal;
  }
}
