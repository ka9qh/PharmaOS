// شاشة تسجيل الدخول - أول شاشة حقيقية وفعّالة في المشروع

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_widget.dart';
import '../../../../core/services/windows_biometric_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _usernameError;
  String? _passwordError;
  bool _obscurePassword = true;
  bool _isBiometricAvailable = false;
  bool _isBiometricLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await WindowsBiometricService.isBiometricAvailable();
    if (mounted) {
      setState(() => _isBiometricAvailable = available);
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() => _isBiometricLoading = true);
    final verified = await WindowsBiometricService.authenticate(
      reason: 'تسجيل الدخول السريع إلى نظام فارما أو إس (PharmaOS)',
    );
    setState(() => _isBiometricLoading = false);
    if (verified) {
      await ref.read(authNotifierProvider.notifier).loginWithBiometrics();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر التحقق بالبصمة أو تم الإلغاء، يرجى إدخال كلمة المرور'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final result = AuthController.validate(
      username: _usernameController.text,
      password: _passwordController.text,
    );
    setState(() {
      _usernameError = result.usernameError;
      _passwordError = result.passwordError;
    });
    if (!result.isValid) return;

    ref.read(authNotifierProvider.notifier).login(
          _usernameController.text,
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // الانتقال لنقطة البيع (الشاشة الرئيسية للنظام) فور نجاح الدخول - إلا إذا
    // كان دور المستخدم لا يملك صلاحية usePos أصلاً (مثل محاسب)، فيُنقل مباشرة
    // للوحة التحكم بدل شاشة بيع لا يستطيع استخدامها. لوحة التحكم تبقى متاحة
    // بضغطة واحدة من داخل شاشة نقطة البيع لمن يملك الصلاحية.
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.isLoggedIn) {
        context.go('/pos');
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AuthLogoHeader(),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم',
                      errorText: _usernameError,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      errorText: _passwordError,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        authState.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _submit,
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text('تسجيل الدخول'),
                    ),
                  ),
                  if (_isBiometricAvailable) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: (_isBiometricLoading || authState.isLoading)
                            ? null
                            : _loginWithBiometrics,
                        icon: _isBiometricLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.fingerprint, color: Colors.teal, size: 26),
                        label: const Text(
                          'تسجيل الدخول السريع ببصمة اللابتوب',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.teal,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.teal, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          'تطوير وهندسة: م/عباد السويدي',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '📞 +967776065503',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
