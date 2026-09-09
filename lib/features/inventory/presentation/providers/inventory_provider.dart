import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/inventory_entity.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/usecases/inventory_usecase.dart';

class InventoryState {
  final bool isLoading;
  final List<StockSummary> items; // Items after search filter
  final List<StockSummary> _allItems; // All fetched items
  final String? errorMessage;
  final String searchQuery;

  const InventoryState({
    this.isLoading = false,
    this.items = const [],
    List<StockSummary>? allItems,
    this.errorMessage,
    this.searchQuery = '',
  }) : _allItems = allItems ?? items;

  InventoryState copyWith({
    bool? isLoading,
    List<StockSummary>? items,
    List<StockSummary>? allItems,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
  }) {
    return InventoryState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      allItems: allItems ?? _allItems,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class InventoryNotifier extends AutoDisposeNotifier<InventoryState> {
  @override
  InventoryState build() {
    Future.microtask(loadAll);
    return const InventoryState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await GetStockOverviewUseCase(sl<InventoryRepository>()).call();
      _updateWithSearch(list, state.searchQuery);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل بيانات المخزون');
    }
  }

  void search(String query) {
    _updateWithSearch(state._allItems, query);
  }

  void _updateWithSearch(List<StockSummary> allItems, String query) {
    if (query.trim().isEmpty) {
      state = state.copyWith(isLoading: false, items: allItems, allItems: allItems, searchQuery: query);
    } else {
      final q = query.trim().toLowerCase();
      final filtered = allItems.where((item) {
        return item.medicineName.toLowerCase().contains(q);
      }).toList();
      state = state.copyWith(isLoading: false, items: filtered, allItems: allItems, searchQuery: query);
    }
  }

  Future<bool> receiveStock({
    required int medicineId,
    String? batchNumber,
    DateTime? expiryDate,
    required int quantity,
    required double purchasePrice,
  }) async {
    try {
      await ReceiveStockUseCase(sl<InventoryRepository>()).call(
        medicineId: medicineId,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        quantity: quantity,
        purchasePrice: purchasePrice,
      );
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تسجيل استلام الكمية');
      return false;
    }
  }

  Future<bool> writeOffStock({
    required int medicineId,
    required int quantity,
    required String reason,
    String? notes,
  }) async {
    try {
      await WriteOffStockUseCase(sl<InventoryRepository>()).call(
        medicineId: medicineId,
        quantity: quantity,
        reason: reason,
        notes: notes,
      );
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تسجيل الإتلاف: $e');
      return false;
    }
  }

  Future<bool> reconcileStock({
    required int medicineId,
    required double actualQuantity,
    required double systemQuantity,
    String? note,
    int? userId,
  }) async {
    try {
      await sl<InventoryRepository>().reconcileStock(
        medicineId: medicineId,
        actualQuantity: actualQuantity,
        systemQuantity: systemQuantity,
        note: note,
        userId: userId,
      );
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر حفظ التسوية الجردية: $e');
      return false;
    }
  }

  Future<bool> deleteStockRecords(int medicineId) async {
    try {
      await DeleteStockRecordsUseCase(sl<InventoryRepository>()).call(medicineId);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إزالة الصنف من المخزون: $e');
      return false;
    }
  }

  Future<bool> deleteSingleBatch(int batchId) async {
    try {
      await sl<InventoryRepository>().deleteSingleBatch(batchId);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إزالة هذه الدفعة من المخزون: $e');
      return false;
    }
  }
}

final inventoryNotifierProvider =
    AutoDisposeNotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);
