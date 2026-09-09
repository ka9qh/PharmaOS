// خدمة الصلاحيات الفعلية (Effective Permissions)
// ============================================================================
// تجمع بين طبقتين:
// 1) الصلاحيات الافتراضية حسب الدور (RoleGuard.defaultsFor) - سريعة، ثابتة بالكود.
// 2) تخصيص فردي لكل مستخدم مخزَّن في جدول user_permissions (تفعيل أو تعطيل
//    صريح لصلاحية معينة، يتجاوز افتراضي الدور) - يحقق متطلب "كل صلاحية
//    مستقلة ويمكن تفعيلها أو تعطيلها" لكل مستخدم على حدة.
//
// قرار تصميم: جدول user_permissions أُنشئ عبر SQL خام (customStatement) في
// migration قاعدة البيانات، وليس كجدول Drift مُعرَّف بصنف Table - لتفادي
// الحاجة لإعادة توليد app_database.g.dart (build_runner) في هذه الدفعة، بنفس
// المنطق المتبع في دفعة تحسين أداء بحث الأدوية السابقة. الاستعلامات هنا كلها
// عبر customSelect/customStatement.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'audit_logger.dart';
import 'role_guard.dart';

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());
final auditLoggerProvider = Provider<AuditLogger>((ref) => throw UnimplementedError());

class PermissionsService {
  final AppDatabase _db;
  final AuditLogger _auditLogger;

  PermissionsService(this._db, this._auditLogger);

  AppPermission? _permissionFromName(String name) {
    for (final p in AppPermission.values) {
      if (p.name == name) return p;
    }
    return null; 
  }

  Future<Map<AppPermission, bool>> getOverrides(int userId) async {
    final rows = await (_db.select(_db.userPermissions)
          ..where((u) => u.userId.equals(userId)))
        .get();

    final result = <AppPermission, bool>{};
    for (final row in rows) {
      final permission = _permissionFromName(row.permission);
      if (permission == null) continue;
      result[permission] = row.isGranted;
    }
    return result;
  }

  Future<Set<AppPermission>> effectivePermissionsFor(int userId, AppRole role) async {
    final effective = Set<AppPermission>.from(RoleGuard.defaultsFor(role));
    final overrides = await getOverrides(userId);
    overrides.forEach((permission, granted) {
      if (granted) {
        effective.add(permission);
      } else {
        effective.remove(permission);
      }
    });
    return effective;
  }

  Future<void> setOverride({
    required int userId,
    required AppPermission permission,
    required bool granted,
    required int changedByUserId,
  }) async {
    final existing = await (_db.select(_db.userPermissions)
          ..where((u) => u.userId.equals(userId) & u.permission.equals(permission.name)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.userPermissions)..where((u) => u.id.equals(existing.id)))
          .write(UserPermissionsCompanion(isGranted: Value(granted)));
    } else {
      await _db.into(_db.userPermissions).insert(
        UserPermissionsCompanion.insert(
          userId: userId,
          permission: permission.name,
          isGranted: Value(granted),
        ),
      );
    }

    await _auditLogger.log(
      actionType: 'PERMISSION_OVERRIDE_SET',
      tableName: 'user_permissions',
      recordId: '$userId:${permission.name}',
      newValue: granted ? 'true' : 'false',
      userId: changedByUserId,
    );
  }

  Future<void> clearOverride({
    required int userId,
    required AppPermission permission,
    required int changedByUserId,
  }) async {
    await (_db.delete(_db.userPermissions)
          ..where((u) => u.userId.equals(userId) & u.permission.equals(permission.name)))
        .go();

    await _auditLogger.log(
      actionType: 'PERMISSION_OVERRIDE_CLEARED',
      tableName: 'user_permissions',
      recordId: '$userId:${permission.name}',
      newValue: 'reset_to_role_default',
      userId: changedByUserId,
    );
  }
}

final permissionsServiceProvider = Provider<PermissionsService>((ref) {
  return PermissionsService(
    ref.read(databaseProvider),
    ref.read(auditLoggerProvider),
  );
});
