class UserFormValidationResult {
  final bool isValid;
  final String? fullNameError;
  final String? usernameError;
  final String? passwordError;

  const UserFormValidationResult({
    required this.isValid,
    this.fullNameError,
    this.usernameError,
    this.passwordError,
  });
}

class UsersController {
  UsersController._();

  static UserFormValidationResult validate({
    required String fullName,
    required String username,
    required String password,
  }) {
    final fullNameError = fullName.trim().isEmpty ? 'ط§ظ„ط±ط¬ط§ط، ط¥ط¯ط®ط§ظ„ ط§ظ„ط§ط³ظ… ط§ظ„ظƒط§ظ…ظ„' : null;

    String? usernameError;
    if (username.trim().isEmpty) {
      usernameError = 'ط§ظ„ط±ط¬ط§ط، ط¥ط¯ط®ط§ظ„ ط§ط³ظ… ظ…ط³طھط®ط¯ظ…';
    } else if (username.trim().length < 3) {
      usernameError = 'ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ… ظ‚طµظٹط± ط¬ط¯ظ‹ط§ (3 ط£ط­ط±ظپ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„)';
    }

    final passwordError = password.length < 6 ? 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظٹط¬ط¨ ط£ظ† طھظƒظˆظ† 6 ط£ط­ط±ظپ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„' : null;

    return UserFormValidationResult(
      isValid: fullNameError == null && usernameError == null && passwordError == null,
      fullNameError: fullNameError,
      usernameError: usernameError,
      passwordError: passwordError,
    );
  }
}
