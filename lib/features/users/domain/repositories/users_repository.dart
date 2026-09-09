import '../entities/users_entity.dart';
import '../../../../core/security/role_guard.dart';

abstract class UsersRepository {
  Future<List<UserAccountEntity>> listUsers();

  Future<UserAccountEntity> createUser({
    required String fullName,
    required String username,
    required String password,
    required AppRole role,
  });

  Future<void> setActive(int userId, bool isActive);

  Future<void> resetPassword(int userId, String newPassword);
}
