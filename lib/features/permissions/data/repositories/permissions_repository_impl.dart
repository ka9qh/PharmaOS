// Feature: permissions
// Layer: data/repositories

import '../../domain/entities/permissions_entity.dart';
import '../../domain/repositories/permissions_repository.dart';
import '../datasources/permissions_datasource.dart';
import '../../../../core/security/role_guard.dart';
import '../../../users/domain/entities/users_entity.dart';
import '../../../users/domain/repositories/users_repository.dart';

class PermissionsRepositoryImpl implements PermissionsRepository {
  final PermissionsDataSource dataSource;
  final UsersRepository usersRepository;

  PermissionsRepositoryImpl({required this.dataSource, required this.usersRepository});

  @override
  Future<List<UserAccountEntity>> listUsers() => usersRepository.listUsers();

  @override
  Future<List<UserPermissionEntity>> getPermissionsFor(int userId, AppRole role) async {
    final defaults = RoleGuard.defaultsFor(role);
    final overrides = await dataSource.getOverrides(userId);

    return AppPermission.values.map((permission) {
      final override = overrides[permission]; // null = لا يوجد تخصيص لهذه الصلاحية
      final effective = override ?? defaults.contains(permission);
      return UserPermissionEntity(permission: permission, effective: effective, override: override);
    }).toList();
  }

  @override
  Future<void> setOverride({
    required int userId,
    required AppPermission permission,
    required bool granted,
    required int changedByUserId,
  }) {
    return dataSource.setOverride(
      userId: userId,
      permission: permission,
      granted: granted,
      changedByUserId: changedByUserId,
    );
  }

  @override
  Future<void> clearOverride({
    required int userId,
    required AppPermission permission,
    required int changedByUserId,
  }) {
    return dataSource.clearOverride(
      userId: userId,
      permission: permission,
      changedByUserId: changedByUserId,
    );
  }
}
