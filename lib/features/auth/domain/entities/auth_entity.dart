// الكيان الأساسي للمستخدم المسجّل دخوله - مستقل عن قاعدة البيانات (Domain Layer)

import '../../../../core/security/role_guard.dart';

class AuthUser {
  final int id;
  final String fullName;
  final String username;
  final AppRole role;

  /// الصلاحيات الفعلية النهائية (افتراضي الدور + أي تخصيص فردي محفوظ في
  /// user_permissions) - تُحسب مرة واحدة عند تسجيل الدخول عبر
  /// PermissionsService وتبقى ثابتة طوال الجلسة. تغييرات الصلاحيات التي
  /// تُجرى أثناء وجود المستخدم بجلسة مفتوحة تُطبَّق من دخوله التالي.
  final Set<AppPermission> effectivePermissions;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
    this.effectivePermissions = const {},
  });

  bool can(AppPermission permission) => effectivePermissions.contains(permission);
}
