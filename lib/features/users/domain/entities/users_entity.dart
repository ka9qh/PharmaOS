import '../../../../core/security/role_guard.dart';

class UserAccountEntity {
  final int id;
  final String fullName;
  final String username;
  final AppRole role;
  final bool isActive;
  final bool mustChangePassword;

  const UserAccountEntity({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
  });
}
