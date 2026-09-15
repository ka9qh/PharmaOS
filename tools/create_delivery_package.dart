import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  final deliveryDir = Directory('C:\\Users\\hp\\Desktop\\ملف التسليم الجاهز');
  print('Creating Clean Delivery Package at: ${deliveryDir.path}');

  if (await deliveryDir.exists()) {
    try {
      await deliveryDir.delete(recursive: true);
    } catch (e) {
      print('Warning deleting old delivery folder: $e');
    }
  }
  await deliveryDir.create(recursive: true);

  final releaseSourceDir = Directory(p.join(Directory.current.path, 'build', 'windows', 'x64', 'runner', 'Release'));
  if (!await releaseSourceDir.exists()) {
    print('ERROR: Build Release directory not found at ${releaseSourceDir.path}');
    return;
  }

  // 1. Copy required Windows executable, DLLs, and data directory
  final requiredFiles = [
    'pharmaos.exe',
    'flutter_windows.dll',
    'sqlite3.dll',
    'pdfium.dll',
    'file_selector_windows_plugin.dll',
    'printing_plugin.dll',
    'screen_retriever_windows_plugin.dll',
    'url_launcher_windows_plugin.dll',
    'window_manager_plugin.dll',
    'native_assets.json',
  ];

  for (final filename in requiredFiles) {
    final src = File(p.join(releaseSourceDir.path, filename));
    if (await src.exists()) {
      final dest = File(p.join(deliveryDir.path, filename));
      await src.copy(dest.path);
      print('✅ Copied: $filename');
    } else {
      print('⚠️ Missing: $filename');
    }
  }

  // Copy data/ directory
  final dataSrc = Directory(p.join(releaseSourceDir.path, 'data'));
  if (await dataSrc.exists()) {
    final dataDest = Directory(p.join(deliveryDir.path, 'data'));
    await _copyDirectory(dataSrc, dataDest);
    print('✅ Copied folder: data/');
  }

  // 2. Copy healthy pre-seeded database
  final dbSources = [
    File('C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db'),
    File(p.join(Directory.current.path, 'pharmaos_secure.db')),
    File('C:\\Users\\hp\\Desktop\\PharmaOS_Release\\pharmaos_secure.db'),
  ];

  File? validDb;
  for (final db in dbSources) {
    if (await db.exists() && await db.length() > 1000000) {
      validDb = db;
      break;
    }
  }

  if (validDb != null) {
    final destDb = File(p.join(deliveryDir.path, 'pharmaos_secure.db'));
    await validDb.copy(destDb.path);
    print('✅ Copied database: pharmaos_secure.db (${await destDb.length() ~/ 1024} KB)');
  } else {
    print('⚠️ Warning: Pre-seeded database not found!');
  }

  // 3. Copy Mobile Owner APK
  final apkSources = [
    File(p.join(Directory.current.path, 'releases', 'PharmaOS_Owner.apk')),
    File(p.join(Directory.current.path, 'mobile', 'pharmaos_owner_app', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk')),
    File('C:\\Users\\hp\\Desktop\\PharmaOS_Release\\تطبيق_المدير_PharmaOS_Owner.apk'),
  ];

  File? validApk;
  for (final apk in apkSources) {
    if (await apk.exists() && await apk.length() > 5000000) {
      validApk = apk;
      break;
    }
  }

  if (validApk != null) {
    final destApk = File(p.join(deliveryDir.path, 'تطبيق_المدير_PharmaOS_Owner.apk'));
    await validApk.copy(destApk.path);
    print('✅ Copied Mobile APK: تطبيق_المدير_PharmaOS_Owner.apk (${await destApk.length() ~/ (1024 * 1024)} MB)');
  } else {
    print('⚠️ Warning: Owner APK not found!');
  }

  // 4. Create Launcher Script
  final launcher = File(p.join(deliveryDir.path, 'تشغيل_نظام_الصيدلية.bat'));
  await launcher.writeAsString('''@echo off
chcp 65001 > nul
title PharmaOS - نظام إدارة الصيدلية المتكامل
echo ================================================================
echo               نظام PharmaOS لإدارة وتشغيل الصيدليات
echo ================================================================
echo جاري إطلاق النظام المكتبي الآن...
cd /d "%~dp0"
start "" "%~dp0pharmaos.exe"
exit
''', mode: FileMode.write);
  print('✅ Created launcher: تشغيل_نظام_الصيدلية.bat');

  // 5. Create Manual Open Shortcut
  final manualBat = File(p.join(deliveryDir.path, 'فتح_دليل_التشغيل.bat'));
  await manualBat.writeAsString('''@echo off
chcp 65001 > nul
start "" "%~dp0دليل_التشغيل_والاستخدام_الشامل.txt"
exit
''', mode: FileMode.write);
  print('✅ Created shortcut: فتح_دليل_التشغيل.bat');

  // 6. Create Comprehensive Operating Manual
  final manualTxt = File(p.join(deliveryDir.path, 'دليل_التشغيل_والاستخدام_الشامل.txt'));
  await manualTxt.writeAsString('''================================================================================
                    دليل التشغيل والاستخدام الشامل لنظام PharmaOS
                        الإصدار المكتبي والهاتفي المتكامل 2026
================================================================================

أهلاً بكم في نظام PharmaOS - المنظومة الأكثر تطوراً واحترافية لإدارة الصيدليات.
تم إعداد هذا الملف لتوضيح كافة خصائص ومميزات وطرق تشغيل النظام لضمان تجربة سلسة وآمنة.

--------------------------------------------------------------------------------
1. التشغيل السريع والإعداد لأول مرة (First-Time Launch & Wizard):
--------------------------------------------------------------------------------
- انقر نقراً مزدوجاً على الملف: [تشغيل_نظام_الصيدلية.bat]
- عند أول تشغيل، ينطلق معالج التهيئة والتشغيل الذكي (Onboarding Setup Wizard) المكون من 8 خطوات احترافية:
  1) اسم الصيدلية والترخيص: توليد كود التفعيل الذكي ([PharmacyName]#[HardwareID]) وتفعيل الترخيص.
  2) الحساب السحابي: ربط حساب الصيدلية لمزامنة السحاب وجوجل درايف (مع إمكانية التخطي).
  3) بنية الأجهزة والفروع: اختيار (جهاز فردي / شبكة كاشيرات محلية / فروع متعددة) وتوليد رموز الاقتران للأجهزة الإضافية (مع إمكانية التخطي).
  4) الشركات الدوائية: اختيار وتفعيل الشركات المصنعة وإضافة شركات جديدة (مع إمكانية التخطي).
  5) الموردون والموزعون: تحديد شبكة الموردين المسجلين أو إضافة مورد جديد (مع إمكانية التخطي).
  6) الذكاء الاصطناعي للفواتير (Gemini Vision): مسح فواتير المشتريات ضوئياً واستخراج الأدوية والكميات تلقائياً (مع إمكانية التخطي).
  7) الجرد والباركود المصنعي: فحص المخزون وربط باركودات البكتات والعلب والكراتين (مع إمكانية التخطي).
  8) إطلاق النظام: الانتقال الفوري والمباشر لشاشة البيع ولوحة التحكم.

--------------------------------------------------------------------------------
2. التوقيت الرسمي ونظام النسخ الاحتياطي الثلاثي الذكي:
--------------------------------------------------------------------------------
يتميز PharmaOS بمحرك نسخ احتياطي ذكي ثلاثي الوجهات (3-Tier Multi-Destination Backup):
1) النسخ الاحتياطي التلقائي عند تغير التاريخ (منتصف الليل 00:00:00):
   - يرصد النظام بدقة فائقة عبر خدمة التوقيت الرسمي لحظة بداية اليوم الجديد ويقوم بتوليد نسخة احتياطية فورية تلقائياً دون أي تدخل يدوي.
2) شاشة النسخ الإلزامي قبل إغلاق النظام (Pre-Exit Mandatory Backup):
   - عند محاولة إغلاق البرنامج، تظهر واجهة إلزامية شفافة تنفذ النسخ عبر القنوات الثلاث المعتمدة وتغلق النظام بأمان تام.
3) القنوات الثلاث المعتمدة للنسخ:
   - قناة 1: قرص التخزين المحلي (ملف مشفر .pharmaos_backup على سطح المكتب).
   - قناة 2: الحساب السحابي المربوط بالصيدلية / Google Drive.
   - قناة 3: الخزينة السحابية الآمنة المشفرة، مع تضمين اسم الصيدلية، التاريخ، التوقيت بالثواني، وحجم النسخة، مع سبب النسخ.

--------------------------------------------------------------------------------
3. إدارة بنية الأجهزة والفروع ورموز الاقتران:
--------------------------------------------------------------------------------
- من خلال قائمة الإعدادات -> [إدارة بنية الأجهزة والفروع ورموز الاقتران]:
- يمكنك توليد رموز اقتران فريدة ومحمية لكل كاشير أو فرع (مثال: PHOS-DEV-01-XXXX-YYYY).
- عند تشغيل النظام على جهاز كاشير إضافي في نفس الصيدلية أو فرع آخر، يكفي إدخال رمز الاقتران ليتم الاتصال والتكامل فوراً.

--------------------------------------------------------------------------------
4. تطبيق الجوال الخاص بمالك الصيدلية (PharmaOS Owner App):
--------------------------------------------------------------------------------
- مرفق في هذا المجلد ملف: [تطبيق_المدير_PharmaOS_Owner.apk]
- يمكن تثبيته على أي هاتف يعمل بنظام أندرويد.
- يتيح لمالك الصيدلية متابعة المبيعات الحية، الأرباح، النواقص، والتنبيهات، والتقارير من أي مكان في العالم.

--------------------------------------------------------------------------------
5. الدعم الفني والتطوير:
--------------------------------------------------------------------------------
تطوير وهندسة برمجية بواسطة:
المهندس / عباد السويدي
هاتف / واتساب: +967776065503
جميع الحقوق محفوظة © PharmaOS 2026
================================================================================
''', mode: FileMode.write);
  print('✅ Created manual: دليل_التشغيل_والاستخدام_الشامل.txt');

  print('\n🎉 Clean Delivery Package created successfully!');
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: false)) {
    final destPath = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(destPath));
    } else if (entity is File) {
      final destFile = File(destPath);
      if (await destFile.exists()) {
        try {
          await destFile.delete();
        } catch (_) {}
      }
      try {
        await entity.copy(destPath);
      } catch (_) {
        await destFile.writeAsBytes(await entity.readAsBytes());
      }
    }
  }
}
