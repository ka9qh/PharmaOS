// عقد Domain لعمليات المصادقة - لا يعرف شيئًا عن قاعدة البيانات أو Drift مباشرة

import '../entities/auth_entity.dart';

abstract class AuthRepository {
  /// يحاول تسجيل الدخول. يُرجع null إذا كانت البيانات غير صحيحة أو الحساب معطّل.
  Future<AuthUser?> login({required String username, required String password});

  /// يسجل عملية الخروج في سجل التدقيق (لا توجد جلسات فعلية محفوظة في Phase 1).
  Future<void> logout(int userId);

  /// يُنشئ حساب "admin" افتراضي إذا كان جدول المستخدمين فارغًا (أول تشغيل للنظام).
  Future<void> ensureDefaultAdminExists();

  /// تسجيل دخول سريع عبر البصمة الحيوية لنظام الويندوز (Windows Hello)
  Future<AuthUser?> loginWithBiometrics({String? username});
}
