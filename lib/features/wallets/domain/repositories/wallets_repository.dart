import '../entities/wallet_entity.dart';

abstract class WalletsRepository {
  Future<List<WalletEntity>> getAll();
  Future<WalletEntity> create(String name);
  Future<WalletEntity> update(int id, String name);
  Future<void> delete(int id);
}
