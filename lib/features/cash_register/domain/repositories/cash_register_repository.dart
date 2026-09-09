import '../entities/cash_register_entity.dart';

abstract class CashRegisterRepository {
  Future<List<WalletEntity>> getWallets();
  Future<void> addWallet(String name);
  Future<void> deleteWallet(int id);
  Future<double> getCashBalance();
  Future<List<TransactionEntity>> getTransactions({int? walletId});
}
