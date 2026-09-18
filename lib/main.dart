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
import 'core/services/official_date_time_service.dart';
import 'core/services/multi_destination_backup_service.dart';
import 'core/services/cloud_backup_service.dart';
import 'core/widgets/pre_exit_backup_dialog.dart';
import 'core/services/owner_live_sync_service.dart';
import 'core/widgets/owner_floating_notification.dart';
import 'features/closing/presentation/widgets/pre_exit_shift_closing_dialog.dart';

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
  await setupServiceLocator();

  // 2) تهيئة خدمة الوقت والتاريخ الرسمي ورصد منتصف الليل التلقائي
  OfficialDateTimeService.initialize();

  // 3) تشغيل محرك المزامنة الحية المباشرة مع تطبيق المدير
  OwnerLiveSyncService.start();

  // 4) التحقق من زراعة قاعدة البيانات والمزامنة السحابية في الخلفية
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

  // 5) فتح مسار التطبيق الأساسي
  final router = AppRouter.build(initialLocation: '/login');

  runApp(
    ProviderScope(
      child: PharmaOSApp(
        router: router,
        builder: (context, child) => OwnerFloatingNotificationOverlay(
          child: AppScreenshotWrapper(child: child!),
        ),
      ),
    ),
  );
  
  // تسجيل مستمع إغلاق النافذة لتنفيذ النسخ الإلزامي قبل الإغلاق
  windowManager.setPreventClose(true);
  windowManager.addListener(_WindowCloseListener());
}

class _WindowCloseListener extends WindowListener {
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      try {
        debugPrint('App closing intercepted. Triggering shift closing & mandatory pre-exit backup dialog...');
        
        final context = AppRouter.rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          await PreExitShiftClosingDialog.show(
            context,
            onProceedToBackupAndExit: () async {
              if (context.mounted) {
                await PreExitBackupDialog.show(context);
              } else {
                await windowManager.destroy();
              }
            },
          );
        } else {
          // في حال عدم توفر السياق، يتم التنفيذ في الخلفية
          await MultiDestinationBackupService.performFullBackup(
            triggerReason: 'نسخ احتياطي إلزامي عند إغلاق النظام (Background Fallback)',
            isSilent: true,
          );
          await windowManager.destroy();
        }
      } catch (e) {
        debugPrint('Error during pre-exit shift closing/backup: $e');
        await windowManager.destroy();
      }
    }
  }
}

