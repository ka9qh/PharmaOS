// Feature: permissions
// Layer: domain/entities
//
// يمثّل حالة صلاحية واحدة لمستخدم واحد: هل هي مفعّلة فعليًا (effective)،
// وهل هذه الحالة قادمة من افتراضي دوره أم من تخصيص صريح له (override).

import '../../../../core/security/role_guard.dart';

class UserPermissionEntity {
  final AppPermission permission;

  /// القيمة الفعلية النهائية بعد تطبيق أي تخصيص فوق افتراضي الدور.
  final bool effective;

  /// null = لا يوجد تخصيص (يتبع افتراضي الدور تلقائيًا).
  /// true/false = مخصَّص صراحة لهذا المستخدم، متجاوزًا افتراضي دوره.
  final bool? override;

  const UserPermissionEntity({
    required this.permission,
    required this.effective,
    required this.override,
  });

  bool get isOverridden => override != null;
}
