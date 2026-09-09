// مصدر البيانات المحلي لميزة المصادقة - يتعامل مباشرة مع جدول users عبر Drift
// لا يوجد أي اتصال بالإنترنت هنا أو في أي مكان آخر بالنظام (Offline-First).

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/password_hasher.dart';

abstract class AuthDataSource {
  Future<UserRow?> findByUsername(String username);
  Future<void> ensureDefaultAdminExists();
}

class AuthDataSourceImpl implements AuthDataSource {
  final AppDatabase _db;
  AuthDataSourceImpl(this._db);

  @override
  Future<UserRow?> findByUsername(String username) {
    return (_db.select(_db.users)
          ..where((u) => u.username.equals(username)))
        .getSingleOrNull();
  }

  @override
  Future<void> ensureDefaultAdminExists() async {
    final existing = await _db.select(_db.users).get();
    if (existing.isEmpty) {
      // حساب افتراضي لأول تشغيل فقط - يُجبر على تغيير كلمة المرور فورًا
      // (mustChangePassword = true). واجهة تغيير كلمة المرور الفعلية تُبنى
      // ضمن ميزة Users/Settings في مرحلة لاحقة من خارطة الطريق.
      await _db.into(_db.users).insert(
            UsersCompanion.insert(
              fullName: 'مدير النظام',
              username: 'admin',
              passwordHash: PasswordHasher.hash('admin123'),
              role: 'owner',
              mustChangePassword: const Value(true),
            ),
          );
    }
  }
}
