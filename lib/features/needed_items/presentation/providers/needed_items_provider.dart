import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/needed_item_entity.dart';
import '../../domain/repositories/needed_items_repository.dart';

class NeededItemsState {
  final bool isLoading;
  final List<NeededItemEntity> items;
  final String? errorMessage;

  const NeededItemsState({this.isLoading = false, this.items = const [], this.errorMessage});

  NeededItemsState copyWith({bool? isLoading, List<NeededItemEntity>? items, String? errorMessage, bool clearError = false}) {
    return NeededItemsState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class NeededItemsNotifier extends AutoDisposeNotifier<NeededItemsState> {
  @override
  NeededItemsState build() {
    Future.microtask(loadAll);
    return const NeededItemsState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await sl<NeededItemsRepository>().getAll();
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل الملاحظات');
    }
  }

  Future<bool> addItem({required String itemName, String? notes, String? customerName}) async {
    try {
      await sl<NeededItemsRepository>().create(itemName: itemName, notes: notes, customerName: customerName);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حفظ الملاحظة');
      return false;
    }
  }

  Future<void> resolveItem(int id) async {
    try {
      await sl<NeededItemsRepository>().resolve(id);
      await loadAll();
    } catch (_) {}
  }

  Future<void> deleteItem(int id) async {
    try {
      await sl<NeededItemsRepository>().delete(id);
      await loadAll();
    } catch (_) {}
  }
}

final neededItemsNotifierProvider =
    AutoDisposeNotifierProvider<NeededItemsNotifier, NeededItemsState>(NeededItemsNotifier.new);
