import '../../domain/entities/notifications_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsDataSource dataSource;
  NotificationsRepositoryImpl(this.dataSource);

  @override
  Future<int> getTotalCount() => dataSource.getTotalCount();

  @override
  Future<List<AppNotification>> getAll() => dataSource.getAll();
}
