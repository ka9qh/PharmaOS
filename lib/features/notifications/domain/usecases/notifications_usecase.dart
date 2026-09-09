import '../entities/notifications_entity.dart';
import '../repositories/notifications_repository.dart';

class GetNotificationsCountUseCase {
  final NotificationsRepository _repo;
  const GetNotificationsCountUseCase(this._repo);
  Future<int> call() => _repo.getTotalCount();
}

class GetAllNotificationsUseCase {
  final NotificationsRepository _repo;
  const GetAllNotificationsUseCase(this._repo);
  Future<List<AppNotification>> call() => _repo.getAll();
}
