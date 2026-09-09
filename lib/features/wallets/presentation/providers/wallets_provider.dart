import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallets_repository.dart';

final walletsRepositoryProvider = Provider<WalletsRepository>((ref) {
  return sl<WalletsRepository>();
});

final walletsNotifierProvider =
    StateNotifierProvider<WalletsNotifier, AsyncValue<List<WalletEntity>>>((ref) {
  return WalletsNotifier(ref.watch(walletsRepositoryProvider));
});

class WalletsNotifier extends StateNotifier<AsyncValue<List<WalletEntity>>> {
  final WalletsRepository repository;

  WalletsNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadWallets();
  }

  Future<void> loadWallets() async {
    try {
      state = const AsyncValue.loading();
      final wallets = await repository.getAll();
      state = AsyncValue.data(wallets);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addWallet(String name) async {
    try {
      final newWallet = await repository.create(name);
      state = state.whenData((wallets) => [...wallets, newWallet]);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateWallet(int id, String name) async {
    try {
      final updatedWallet = await repository.update(id, name);
      state = state.whenData((wallets) {
        return wallets.map((w) => w.id == id ? updatedWallet : w).toList();
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteWallet(int id) async {
    try {
      await repository.delete(id);
      state = state.whenData((wallets) {
        return wallets.where((w) => w.id != id).toList();
      });
    } catch (e) {
      rethrow;
    }
  }
}
