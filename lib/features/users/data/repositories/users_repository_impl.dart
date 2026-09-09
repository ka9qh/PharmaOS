import '../../domain/entities/users_entity.dart';
import '../../domain/repositories/users_repository.dart';
import '../datasources/users_datasource.dart';
import '../models/users_model.dart';
import '../../../../core/security/password_hasher.dart';
import '../../../../core/security/role_guard.dart';
import '../../../../core/security/audit_logger.dart';
import '../../../../core/errors/app_exceptions.dart';

class UsersRepositoryImpl implements UsersRepository {
  final UsersDataSource dataSource;
  final AuditLogger auditLogger;

  UsersRepositoryImpl({required this.dataSource, required this.auditLogger});

  @override
  Future<List<UserAccountEntity>> listUsers() async {
    final rows = await dataSource.listUsers();
    return rows.map((r) => r.toAccountEntity()).toList();
  }

  @override
  Future<UserAccountEntity> createUser({
    required String fullName,
    required String username,
    required String password,
    required AppRole role,
  }) async {
    final exists = await dataSource.usernameExists(username.trim());
    if (exists) {
      throw AppException('ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ… "$username" ظ…ط³طھط®ط¯ظ… ط¨ط§ظ„ظپط¹ظ„ - ط§ط®طھط± ط§ط³ظ…ظ‹ط§ ط¢ط®ط±');
    }

    final row = await dataSource.createUser(
      fullName: fullName.trim(),
      username: username.trim(),
      passwordHash: PasswordHasher.hash(password),
      role: role.name,
    );

    await auditLogger.log(
      actionType: 'USER_CREATED',
      tableName: 'users',
      recordId: row.id.toString(),
      newValue: 'username=${row.username}, role=${role.name}',
    );

    return row.toAccountEntity();
  }

  @override
  Future<void> setActive(int userId, bool isActive) async {
    await dataSource.setActive(userId, isActive);
    await auditLogger.log(
      actionType: isActive ? 'USER_ACTIVATED' : 'USER_DEACTIVATED',
      tableName: 'users',
      recordId: userId.toString(),
    );
  }

  @override
  Future<void> resetPassword(int userId, String newPassword) async {
    await dataSource.resetPassword(userId, PasswordHasher.hash(newPassword));
    await auditLogger.log(
      actionType: 'PASSWORD_RESET',
      tableName: 'users',
      recordId: userId.toString(),
    );
  }
}
