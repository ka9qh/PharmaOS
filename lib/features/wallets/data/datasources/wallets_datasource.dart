import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class WalletsDataSource {
  final AppDatabase db;

  WalletsDataSource(this.db);

  Future<List<WalletRow>> getAll() async {
    return await db.select(db.wallets).get();
  }

  Future<WalletRow> create(String name) async {
    final companion = WalletsCompanion.insert(
      name: name.trim(),
    );
    final row = await db.into(db.wallets).insertReturning(companion);
    return row;
  }

  Future<WalletRow> update(int id, String name) async {
    final companion = WalletsCompanion(name: Value(name.trim()));
    final updatedRows = await (db.update(db.wallets)..where((t) => t.id.equals(id)))
        .writeReturning(companion);
    return updatedRows.first;
  }

  Future<void> delete(int id) async {
    await (db.delete(db.wallets)..where((t) => t.id.equals(id))).go();
  }
}
