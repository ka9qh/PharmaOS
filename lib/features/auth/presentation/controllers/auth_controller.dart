// يفصل منطق التحقق من صحة مدخلات شاشة تسجيل الدخول عن الشاشة نفسها.

class AuthFormValidationResult {
  final bool isValid;
  final String? usernameError;
  final String? passwordError;

  const AuthFormValidationResult({
    required this.isValid,
    this.usernameError,
    this.passwordError,
  });
}

class AuthController {
  AuthController._();

  static AuthFormValidationResult validate({
    required String username,
    required String password,
  }) {
    final usernameError = username.trim().isEmpty ? 'الرجاء إدخال اسم المستخدم' : null;
    final passwordError = password.isEmpty ? 'الرجاء إدخال كلمة المرور' : null;

    return AuthFormValidationResult(
      isValid: usernameError == null && passwordError == null,
      usernameError: usernameError,
      passwordError: passwordError,
    );
  }
}
