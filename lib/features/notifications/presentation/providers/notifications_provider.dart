import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/notifications_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/usecases/notifications_usecase.dart';

class NotificationsState {
  final bool isLoading;
  final int count;
  final List<AppNotification> items;

  const NotificationsState({this.isLoading = false, this.count = 0, this.items = const []});

  NotificationsState copyWith({bool? isLoading, int? count, List<AppNotification>? items}) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      count: count ?? this.count,
      items: items ?? this.items,
    );
  }
}

class NotificationsNotifier extends AutoDisposeNotifier<NotificationsState> {
  @override
  NotificationsState build() {
    Future.microtask(loadAll);
    return const NotificationsState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final items = await GetAllNotificationsUseCase(sl<NotificationsRepository>()).call();
    state = state.copyWith(isLoading: false, items: items, count: items.length);
  }
}

final notificationsNotifierProvider =
    AutoDisposeNotifierProvider<NotificationsNotifier, NotificationsState>(NotificationsNotifier.new);
