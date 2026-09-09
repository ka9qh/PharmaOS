import '../entities/users_entity.dart';
import '../repositories/users_repository.dart';
import '../../../../core/security/role_guard.dart';

class ListUsersUseCase {
  final UsersRepository _repo;
  const ListUsersUseCase(this._repo);
  Future<List<UserAccountEntity>> call() => _repo.listUsers();
}

class CreateUserUseCase {
  final UsersRepository _repo;
  const CreateUserUseCase(this._repo);
  Future<UserAccountEntity> call({
    required String fullName,
    required String username,
    required String password,
    required AppRole role,
  }) {
    return _repo.createUser(fullName: fullName, username: username, password: password, role: role);
  }
}

class SetUserActiveUseCase {
  final UsersRepository _repo;
  const SetUserActiveUseCase(this._repo);
  Future<void> call(int userId, bool isActive) => _repo.setActive(userId, isActive);
}

class ResetPasswordUseCase {
  final UsersRepository _repo;
  const ResetPasswordUseCase(this._repo);
  Future<void> call(int userId, String newPassword) => _repo.resetPassword(userId, newPassword);
}
