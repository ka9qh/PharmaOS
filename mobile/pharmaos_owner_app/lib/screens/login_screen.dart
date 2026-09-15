// شاشة تسجيل الدخول برمز التفعيل الشامل للصيدلية - PharmaOS Owner App
import 'package:flutter/material.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    final config = await OwnerApiService.getConfig();
    if (config != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  Future<void> _handleLogin() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رمز التفعيل الخاص بالصيدلية');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final config = await OwnerApiService.loginWithActivationKey(key);

    if (mounted) {
      setState(() => _isLoading = false);
      if (config != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        setState(() => _errorMessage = 'تعذر التعرف على رمز التفعيل، تأكد من صحة الرمز');
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: OwnerTheme.bgMeshGradient,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // الشعار والأيقونة بتأثير متوهج
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: OwnerTheme.emeraldGradient,
                        boxShadow: [
                          BoxShadow(
                            color: OwnerTheme.primaryEmerald.withOpacity(0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // العنوان والوصف
                    const Text(
                      'PharmaOS Owner',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'منظومة المراقبة والتحكم المباشر للمدير العام',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // بطاقة تسجيل الدخول الزجاجية
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: OwnerTheme.glassCardDecoration(
                        borderColor: OwnerTheme.primaryEmerald.withOpacity(0.3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.vpn_key_rounded, color: OwnerTheme.accentGold, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'رمز تفعيل الصيدلية الأساسي',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'أدخل رمز التفعيل الخاص بصيدليتك الأساسية ليتم ربط كافة الفروع والأجهزة والبيانات تلقائياً دون أي تداخل.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          TextField(
                            controller: _keyController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              letterSpacing: 1.1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'مثال: صيدلية_النور#HWID-XXXX-XXXX أو المفتاح السحابي',
                              prefixIcon: Icon(Icons.security_rounded, color: OwnerTheme.primaryEmeraldLight),
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OwnerTheme.primaryEmerald,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock_open_rounded, size: 20),
                                        SizedBox(width: 10),
                                        Text('دخول لوحة تحكم المدير', style: TextStyle(fontSize: 16)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // مزايا النظام
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FeatureBadge(icon: Icons.videocam_rounded, label: 'بث حي للشاشة والكاميرا'),
                        const SizedBox(width: 16),
                        _FeatureBadge(icon: Icons.price_change_rounded, label: 'تعديل الأسعار والمخزون'),
                        const SizedBox(width: 16),
                        _FeatureBadge(icon: Icons.cloud_sync_rounded, label: 'نسخ ثلاثي فوري'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(color: OwnerTheme.surfaceBorder),
          ),
          child: Icon(icon, color: OwnerTheme.accentGoldLight, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
        ),
      ],
    );
  }
}
