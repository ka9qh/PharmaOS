import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/entities/workers_entity.dart';
import '../../domain/repositories/workers_repository.dart';

class WorkersState {
  final bool isLoading;
  final List<WorkerEntity> workers;
  final String? errorMessage;
  final String searchQuery;

  const WorkersState({
    this.isLoading = false,
    this.workers = const [],
    this.errorMessage,
    this.searchQuery = '',
  });

  WorkersState copyWith({
    bool? isLoading,
    List<WorkerEntity>? workers,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
  }) {
    return WorkersState(
      isLoading: isLoading ?? this.isLoading,
      workers: workers ?? this.workers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class WorkersNotifier extends AutoDisposeNotifier<WorkersState> {
  late WorkersRepository _repository;

  @override
  WorkersState build() {
    _repository = sl<WorkersRepository>();
    Future.microtask(loadWorkers);
    return const WorkersState();
  }

  Future<void> loadWorkers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repository.getAllWorkers();
      state = state.copyWith(isLoading: false, workers: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر جلب بيانات الموظفين: $e');
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  List<WorkerEntity> get filteredWorkers {
    final q = state.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return state.workers;
    return state.workers.where((w) => w.name.toLowerCase().contains(q) || (w.phone?.contains(q) ?? false)).toList();
  }

  Future<bool> createWorker({
    required String name,
    String? phone,
    required double salary,
    double? dailyWithdrawalLimit,
    required bool allowanceIsDeducted,
    String? notes,
  }) async {
    try {
      await _repository.createWorker(
        name: name,
        phone: phone,
        salary: salary,
        dailyWithdrawalLimit: dailyWithdrawalLimit,
        allowanceIsDeducted: allowanceIsDeducted,
        notes: notes,
      );
      await loadWorkers();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إضافة الموظف: $e');
      return false;
    }
  }

  Future<bool> updateWorker({
    required int id,
    required String name,
    String? phone,
    required double salary,
    double? dailyWithdrawalLimit,
    required bool allowanceIsDeducted,
    String? notes,
  }) async {
    try {
      await _repository.updateWorker(
        id: id,
        name: name,
        phone: phone,
        salary: salary,
        dailyWithdrawalLimit: dailyWithdrawalLimit,
        allowanceIsDeducted: allowanceIsDeducted,
        notes: notes,
      );
      await loadWorkers();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر تحديث الموظف: $e');
      return false;
    }
  }

  Future<bool> archiveWorker(int id) async {
    try {
      await _repository.archiveWorker(id);
      await loadWorkers();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر أرشفة الموظف: $e');
      return false;
    }
  }
}

final workersNotifierProvider = AutoDisposeNotifierProvider<WorkersNotifier, WorkersState>(WorkersNotifier.new);
