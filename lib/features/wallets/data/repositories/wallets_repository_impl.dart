import '../../../../core/database/app_database.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallets_repository.dart';
import '../datasources/wallets_datasource.dart';

class WalletsRepositoryImpl implements WalletsRepository {
  final WalletsDataSource dataSource;

  WalletsRepositoryImpl({required this.dataSource});

  WalletEntity _mapRow(WalletRow row) {
    return WalletEntity(
      id: row.id,
      name: row.name,
      createdAt: row.createdAt,
    );
  }

  @override
  Future<List<WalletEntity>> getAll() async {
    final rows = await dataSource.getAll();
    return rows.map(_mapRow).toList();
  }

  @override
  Future<WalletEntity> create(String name) async {
    final row = await dataSource.create(name);
    return _mapRow(row);
  }

  @override
  Future<WalletEntity> update(int id, String name) async {
    final row = await dataSource.update(id, name);
    return _mapRow(row);
  }

  @override
  Future<void> delete(int id) async {
    await dataSource.delete(id);
  }
}
