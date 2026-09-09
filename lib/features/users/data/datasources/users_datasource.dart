import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/password_hasher.dart';

abstract class UsersDataSource {
  Future<List<UserRow>> listUsers();
  Future<bool> usernameExists(String username);
  Future<UserRow> createUser({
    required String fullName,
    required String username,
    required String passwordHash,
    required String role,
  });
  Future<void> setActive(int userId, bool isActive);
  Future<void> resetPassword(int userId, String newPasswordHash);
}

class UsersDataSourceImpl implements UsersDataSource {
  final AppDatabase _db;
  UsersDataSourceImpl(this._db);

  @override
  Future<List<UserRow>> listUsers() {
    return (_db.select(_db.users)..orderBy([(u) => OrderingTerm.asc(u.fullName)])).get();
  }

  @override
  Future<bool> usernameExists(String username) async {
    final existing = await (_db.select(_db.users)..where((u) => u.username.equals(username)))
        .getSingleOrNull();
    return existing != null;
  }

  @override
  Future<UserRow> createUser({
    required String fullName,
    required String username,
    required String passwordHash,
    required String role,
  }) async {
    final id = await _db.into(_db.users).insert(
          UsersCompanion.insert(
            fullName: fullName,
            username: username,
            passwordHash: passwordHash,
            role: role,
            mustChangePassword: const Value(true),
          ),
        );
    return (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingle();
  }

  @override
  Future<void> setActive(int userId, bool isActive) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(userId)))
        .write(UsersCompanion(isActive: Value(isActive)));
  }

  @override
  Future<void> resetPassword(int userId, String newPasswordHash) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(passwordHash: Value(newPasswordHash), mustChangePassword: const Value(true)),
    );
  }
}
