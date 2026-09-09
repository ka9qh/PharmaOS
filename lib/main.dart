// نقطة الدخول الرئيسية لتطبيق PharmaOS
// تفتح شاشة تسجيل الدخول مباشرة وبأقصى سرعة مع التهيئة في الخلفية
// ودعم التقاط الشاشة عبر F9 والزر الصغير

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/app_router.dart';
import 'core/di/service_locator.dart';
import 'core/services/database_seeder_service.dart';
import 'core/widgets/app_screenshot_wrapper.dart';
import 'core/services/cloud_backup_service.dart';
import 'features/closing/domain/services/daily_closing_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    title: 'PharmaOS - نظام الصيدليات المتطور',
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 1) فتح قاعدة البيانات المشفرة + تسجيل جميع الاعتماديات (GetIt)
  // 2) إنشاء حساب "admin" الافتراضي تلقائيًا إذا كانت هذه أول تشغيل للنظام
  await setupServiceLocator();

  // 3) التحقق من زراعة قاعدة البيانات في الخلفية بدون حجب شاشة الدخول
  Future.microtask(() async {
    try {
      final seeder = sl<DatabaseSeederService>();
      await seeder.seedDatabaseIfEmpty();
      // فحص المزامنة السحابية التلقائية الصامتة فور توفر النت
      await CloudBackupService.triggerBackgroundAutoSync();
    } catch (e) {
      debugPrint('Background seeder check: $e');
    }
  });

  // 4) فتح شاشة الدخول مباشرة
  final router = AppRouter.build(initialLocation: '/login');

  runApp(
    ProviderScope(
      child: PharmaOSApp(
        router: router,
        builder: (context, child) => AppScreenshotWrapper(child: child!),
      ),
    ),
  );
  
  // تسجيل مستمع إغلاق النافذة لحفظ الإغلاق اليومي تلقائياً
  windowManager.setPreventClose(true);
  windowManager.addListener(_WindowCloseListener());
}

class _WindowCloseListener extends WindowListener {
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      try {
        debugPrint('App closing intercepted. Performing automatic daily closing snapshot...');
        await DailyClosingService.performDailyClosing(null);
      } catch (e) {
        debugPrint('Error during auto daily closing on exit: $e');
      } finally {
        await windowManager.destroy();
      }
    }
  }
}
