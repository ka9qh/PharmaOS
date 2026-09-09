// حالات استخدام ميزة المصادقة
// ملاحظة: كلا الحالتين هنا في ملف واحد لأن Skeleton الأصلي (Phase 0) أنشأ ملفًا واحدًا
// فقط لطبقة usecases لكل ميزة. لا مانع من عدة أصناف صغيرة داخل نفس الملف طالما مترابطة.

import '../entities/auth_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;
  const LoginUseCase(this._repository);

  Future<AuthUser?> call({required String username, required String password}) {
    return _repository.login(username: username, password: password);
  }
}

class LogoutUseCase {
  final AuthRepository _repository;
  const LogoutUseCase(this._repository);

  Future<void> call(int userId) {
    return _repository.logout(userId);
  }
}
