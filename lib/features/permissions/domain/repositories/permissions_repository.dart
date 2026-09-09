// Feature: permissions
// Layer: domain/repositories

import '../entities/permissions_entity.dart';
import '../../../../core/security/role_guard.dart';
import '../../../users/domain/entities/users_entity.dart';

abstract class PermissionsRepository {
  /// إعادة استخدام قائمة المستخدمين الموجودة (لا تكرار لمنطق ميزة Users).
  Future<List<UserAccountEntity>> listUsers();

  /// كل الصلاحيات الـ 14 مع حالتها الفعلية لمستخدم معيّن.
  Future<List<UserPermissionEntity>> getPermissionsFor(int userId, AppRole role);

  Future<void> setOverride({
    required int userId,
    required AppPermission permission,
    required bool granted,
    required int changedByUserId,
  });

  Future<void> clearOverride({
    required int userId,
    required AppPermission permission,
    required int changedByUserId,
  });
}
