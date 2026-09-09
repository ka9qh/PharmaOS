import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/backup_entity.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../domain/usecases/backup_usecase.dart';

class BackupState {
  final bool isLoading;
  final bool isCreating;
  final List<BackupFileInfo> backups;
  final String? lastCreatedPath;

  const BackupState({
    this.isLoading = false,
    this.isCreating = false,
    this.backups = const [],
    this.lastCreatedPath,
  });

  BackupState copyWith({
    bool? isLoading,
    bool? isCreating,
    List<BackupFileInfo>? backups,
    String? lastCreatedPath,
  }) {
    return BackupState(
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      backups: backups ?? this.backups,
      lastCreatedPath: lastCreatedPath ?? this.lastCreatedPath,
    );
  }
}

class BackupNotifier extends AutoDisposeNotifier<BackupState> {
  @override
  BackupState build() {
    Future.microtask(loadAll);
    return const BackupState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final backups = await ListBackupsUseCase(sl<BackupRepository>()).call();
    state = state.copyWith(isLoading: false, backups: backups);
  }

  Future<void> createNow() async {
    state = state.copyWith(isCreating: true);
    final path = await CreateBackupNowUseCase(sl<BackupRepository>()).call();
    state = state.copyWith(isCreating: false, lastCreatedPath: path);
    await loadAll();
  }
}

final backupNotifierProvider = AutoDisposeNotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
