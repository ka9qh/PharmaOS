// تحويل صف قاعدة البيانات (UserRow من Drift) إلى الكيان AuthUser في طبقة Domain
// هذا هو دور طبقة Models: عزل تفاصيل قاعدة البيانات عن منطق الأعمال.
//
// تحديث: effectivePermissions تُمرَّر من الخارج (محسوبة مسبقًا في
// AuthRepositoryImpl عبر PermissionsService) بدل أن يقرأها هذا الـ mapper
// بنفسه - يبقى toEntity() دالة متزامنة بسيطة بدون أي وصول لقاعدة البيانات.

import '../../../../core/database/app_database.dart';
import '../../../../core/security/role_guard.dart';
import '../../domain/entities/auth_entity.dart';

extension UserRowMapper on UserRow {
  AuthUser toEntity({Set<AppPermission> effectivePermissions = const {}}) {
    return AuthUser(
      id: id,
      fullName: fullName,
      username: username,
      role: RoleGuard.roleFromString(role),
      effectivePermissions: effectivePermissions,
    );
  }
}
