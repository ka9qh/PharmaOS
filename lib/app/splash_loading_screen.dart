// شاشة البداية مع شريط تحميل زراعة قاعدة البيانات
// تظهر عند أول تشغيل أو عند الحاجة لتهيئة النظام ثم تنتقل مباشرة لشاشة الدخول عبر GoRouter

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/di/service_locator.dart';
import '../core/services/database_seeder_service.dart';
import '../core/services/device_branch_manager_service.dart';
import '../features/accounting/domain/repositories/general_ledger_repository.dart';
import '../features/licensing/domain/repositories/licensing_repository.dart';

class SplashLoadingScreen extends StatefulWidget {
  const SplashLoadingScreen({super.key});

  @override
  State<SplashLoadingScreen> createState() => _SplashLoadingScreenState();
}

class _SplashLoadingScreenState extends State<SplashLoadingScreen>
    with SingleTickerProviderStateMixin {
  String _statusText = 'جاري تهيئة النظام...';
  double _progress = 0.0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _startInitialization();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startInitialization() async {
    try {
      // 1. فحص قاعدة البيانات
      if (mounted) {
        setState(() {
          _statusText = 'جاري فحص قاعدة البيانات...';
          _progress = 0.2;
        });
      }
      await Future.delayed(const Duration(milliseconds: 200));

      // 2. زراعة الأدوية إذا كانت فارغة
      if (mounted) {
        setState(() {
          _statusText = 'جاري تحميل كتالوج الأدوية الشامل...';
          _progress = 0.4;
        });
      }

      final seeder = sl<DatabaseSeederService>();
      await seeder.seedDatabaseIfEmpty();

      if (mounted) {
        setState(() {
          _statusText = 'تم تحميل الأدوية بنجاح ✓';
          _progress = 0.7;
        });
      }
      await Future.delayed(const Duration(milliseconds: 200));

      // 3. تهيئة الحسابات المحاسبية
      if (mounted) {
        setState(() {
          _statusText = 'جاري تهيئة النظام المحاسبي...';
          _progress = 0.85;
        });
      }

      final glRepo = sl<GeneralLedgerRepository>();
      await glRepo.seedDefaultAccountsIfEmpty();

      // 4. التحقق من الترخيص
      if (mounted) {
        setState(() {
          _statusText = 'جاري التحقق من الترخيص وفتح النظام...';
          _progress = 1.0;
        });
      }
      await Future.delayed(const Duration(milliseconds: 400));

      final isLicensed = await sl<LicensingRepository>().hasValidLicense();
      final isFirstRunDone = await DeviceBranchManagerService.isFirstRunCompleted();

      if (mounted) {
        if (!isLicensed || !isFirstRunDone) {
          context.go('/onboarding');
        } else {
          context.go('/login');
        }
      }
    } catch (e) {
      debugPrint('⚠️ خطأ في التهيئة الأولية: $e');
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // شعار النظام
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.05),
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_pharmacy,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // اسم النظام
              const Text(
                'PharmaOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'نظام إدارة الصيدليات المتكامل',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 48),

              // شريط التقدم
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0D9488),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 64),

              // تذييل الصفحة
              const Text(
                'الإصدار 2.0.0 | جميع الحقوق محفوظة © 2026',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
