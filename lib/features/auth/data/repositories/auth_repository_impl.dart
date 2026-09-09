// التنفيذ الفعلي لعقد AuthRepository، باستخدام AuthDataSource المحلي فقط
// وتسجيل كل محاولة دخول (ناجحة أو فاشلة) في سجل التدقيق (Audit Log).
//
// تحديث: عند نجاح الدخول، تُحسب الصلاحيات الفعلية النهائية للمستخدم (افتراضي
// دوره + أي تخصيص فردي محفوظ له) مرة واحدة عبر PermissionsService، وتُخزَّن
// في AuthUser طوال الجلسة - بدل إعادة استعلام قاعدة البيانات في كل شاشة.

import '../../domain/entities/auth_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';
import '../models/auth_model.dart';
import '../../../../core/security/password_hasher.dart';
import '../../../../core/security/audit_logger.dart';
import '../../../../core/security/permissions_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;
  final AuditLogger auditLogger;
  final PermissionsService permissionsService;

  AuthRepositoryImpl({
    required this.dataSource,
    required this.auditLogger,
    required this.permissionsService,
  });

  @override
  Future<AuthUser?> login({required String username, required String password}) async {
    final row = await dataSource.findByUsername(username.trim());

    if (row == null || !row.isActive) {
      await auditLogger.log(
        actionType: 'LOGIN_FAILED',
        tableName: 'users',
        recordId: username.trim(),
      );
      return null;
    }

    final passwordMatches = PasswordHasher.verify(password, row.passwordHash);
    if (!passwordMatches) {
      await auditLogger.log(
        actionType: 'LOGIN_FAILED',
        tableName: 'users',
        recordId: row.id.toString(),
        userId: row.id,
      );
      return null;
    }

    await auditLogger.log(
      actionType: 'LOGIN_SUCCESS',
      tableName: 'users',
      recordId: row.id.toString(),
      userId: row.id,
    );

    final entityRole = row.toEntity().role; // تحويل نص role لقيمة AppRole بدون تكرار المنطق
    final effectivePermissions =
        await permissionsService.effectivePermissionsFor(row.id, entityRole);
    return row.toEntity(effectivePermissions: effectivePermissions);
  }

  @override
  Future<void> logout(int userId) async {
    await auditLogger.log(
      actionType: 'LOGOUT',
      tableName: 'users',
      recordId: userId.toString(),
      userId: userId,
    );
  }

  @override
  Future<void> ensureDefaultAdminExists() {
    return dataSource.ensureDefaultAdminExists();
  }

  @override
  Future<AuthUser?> loginWithBiometrics({String? username}) async {
    final targetUser = username?.trim() ?? 'admin';
    final row = await dataSource.findByUsername(targetUser);
    if (row == null || !row.isActive) return null;

    await auditLogger.log(
      actionType: 'BIOMETRIC_LOGIN_SUCCESS',
      tableName: 'users',
      recordId: row.id.toString(),
      userId: row.id,
    );

    final entityRole = row.toEntity().role;
    final effectivePermissions =
        await permissionsService.effectivePermissionsFor(row.id, entityRole);
    return row.toEntity(effectivePermissions: effectivePermissions);
  }
}
