// Feature: permissions
// Layer: domain/usecases
// (عدة حالات استخدام صغيرة مترابطة في ملف واحد - نفس نمط auth_usecase.dart)

import '../entities/permissions_entity.dart';
import '../repositories/permissions_repository.dart';
import '../../../../core/security/role_guard.dart';
import '../../../users/domain/entities/users_entity.dart';

class ListUsersForPermissionsUseCase {
  final PermissionsRepository _repository;
  const ListUsersForPermissionsUseCase(this._repository);
  Future<List<UserAccountEntity>> call() => _repository.listUsers();
}

class GetUserPermissionsUseCase {
  final PermissionsRepository _repository;
  const GetUserPermissionsUseCase(this._repository);
  Future<List<UserPermissionEntity>> call(int userId, AppRole role) =>
      _repository.getPermissionsFor(userId, role);
}

class SetPermissionOverrideUseCase {
  final PermissionsRepository _repository;
  const SetPermissionOverrideUseCase(this._repository);
  Future<void> call({
    required int userId,
    required AppPermission permission,
    required bool granted,
    required int changedByUserId,
  }) {
    return _repository.setOverride(
      userId: userId,
      permission: permission,
      granted: granted,
      changedByUserId: changedByUserId,
    );
  }
}

class ClearPermissionOverrideUseCase {
  final PermissionsRepository _repository;
  const ClearPermissionOverrideUseCase(this._repository);
  Future<void> call({
    required int userId,
    required AppPermission permission,
    required int changedByUserId,
  }) {
    return _repository.clearOverride(
      userId: userId,
      permission: permission,
      changedByUserId: changedByUserId,
    );
  }
}
