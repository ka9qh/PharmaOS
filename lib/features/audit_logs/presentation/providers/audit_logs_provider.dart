import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/audit_logs_entity.dart';
import '../../domain/repositories/audit_logs_repository.dart';
import '../../domain/usecases/audit_logs_usecase.dart';

class AuditLogsState {
  final bool isLoading;
  final List<AuditLogEntryEntity> items;

  const AuditLogsState({this.isLoading = false, this.items = const []});

  AuditLogsState copyWith({bool? isLoading, List<AuditLogEntryEntity>? items}) {
    return AuditLogsState(isLoading: isLoading ?? this.isLoading, items: items ?? this.items);
  }
}

class AuditLogsNotifier extends AutoDisposeNotifier<AuditLogsState> {
  @override
  AuditLogsState build() {
    Future.microtask(loadRecent);
    return const AuditLogsState();
  }

  Future<void> loadRecent() async {
    state = state.copyWith(isLoading: true);
    final items = await ListRecentAuditLogsUseCase(sl<AuditLogsRepository>()).call();
    state = state.copyWith(isLoading: false, items: items);
  }
}

final auditLogsNotifierProvider =
    AutoDisposeNotifierProvider<AuditLogsNotifier, AuditLogsState>(AuditLogsNotifier.new);
