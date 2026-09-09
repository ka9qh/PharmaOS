import '../../../../core/database/app_database.dart';
import '../../../../core/security/role_guard.dart';
import '../../domain/entities/users_entity.dart';

extension UserRowToAccountMapper on UserRow {
  UserAccountEntity toAccountEntity() => UserAccountEntity(
        id: id,
        fullName: fullName,
        username: username,
        role: RoleGuard.roleFromString(role),
        isActive: isActive,
        mustChangePassword: mustChangePassword,
      );
}
