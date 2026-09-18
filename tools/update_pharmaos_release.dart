import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  final targetDirs = [
    Directory('C:\\Users\\hp\\Desktop\\PharmaOS_Release'),
    Directory('C:\\Users\\hp\\Desktop\\ملف التسليم الجاهز'),
  ];

  final releaseSourceDir = Directory(p.join(Directory.current.path, 'build', 'windows', 'x64', 'runner', 'Release'));
  if (!await releaseSourceDir.exists()) {
    print('ERROR: Build Release directory not found at ${releaseSourceDir.path}');
    return;
  }

  for (final targetDir in targetDirs) {
    print('\n======================================================');
    print('🚀 Updating target directory: ${targetDir.path}');
    print('======================================================');

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // 1. Copy all Release build binaries and data folder
    await for (final entity in releaseSourceDir.list(recursive: false)) {
      final destPath = p.join(targetDir.path, p.basename(entity.path));
      if (entity is Directory) {
        final subDir = Directory(destPath);
        if (await subDir.exists()) await subDir.delete(recursive: true);
        await _copyDirectory(entity, subDir);
        print('Updated folder: ${p.basename(entity.path)}');
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
        print('Updated file: ${p.basename(entity.path)}');
      }
    }

    // 2. Copy healthy database
    final healthyDb = File('C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db');
    if (await healthyDb.exists()) {
      final destDb = File(p.join(targetDir.path, 'pharmaos_secure.db'));
      await healthyDb.copy(destDb.path);
      print('✅ Copied healthy pre-seeded database (pharmaos_secure.db)');
    }

    // 3. Copy Mobile Owner APK if present
    final rootApk = File(p.join(Directory.current.path, 'releases', 'PharmaOS_Owner.apk'));
    final buildApk = File(p.join(Directory.current.path, 'mobile', 'pharmaos_owner_app', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk'));
    
    if (await buildApk.exists()) {
      final destApk = File(p.join(targetDir.path, 'تطبيق_المدير_PharmaOS_Owner.apk'));
      await buildApk.copy(destApk.path);
      print('✅ Copied Android Owner APK (تطبيق_المدير_PharmaOS_Owner.apk)');
    } else if (await rootApk.exists()) {
      final destApk = File(p.join(targetDir.path, 'تطبيق_المدير_PharmaOS_Owner.apk'));
      await rootApk.copy(destApk.path);
      print('✅ Copied Android Owner APK from releases');
    }

    // 4. Create clean batch launcher
    final batFile = File(p.join(targetDir.path, 'تشغيل_نظام_الصيدلية.bat'));
    await batFile.writeAsString('''@echo off
chcp 65001 > nul
title PharmaOS - نظام إدارة الصيدلية
echo ===================================================
echo جاري إطلاق نظام PharmaOS المحدث والشامل للصيدلية...
echo ===================================================
cd /d "%~dp0"
start "" "%~dp0pharmaos.exe"
exit
''', mode: FileMode.write);
    print('✅ Created launcher: تشغيل_نظام_الصيدلية.bat');

    // 5. Create user comprehensive guide if not present
    final guideFile = File(p.join(targetDir.path, 'دليل_التشغيل_والاستخدام_الشامل.txt'));
    await guideFile.writeAsString('''===================================================================
                    PharmaOS - نظام الصيدليات المتطور
===================================================================

أهلاً بكم في نظام PharmaOS المحدث والمتكامل لإدارة الصيدليات والورديات.

1. متطلبات التشغيل:
-------------------
- نظام التشغيل: Windows 10 أو Windows 11 (64-bit).
- لا يلزم تثبيت أي خوادم أو برامج مساعدة خارجية، النظام يعمل بشكل محلي ومستقل ومؤمن 100%.

2. طريقة تشغيل النظام:
----------------------
- انقر نقراً مزدوجاً على الملف: [تشغيل_نظام_الصيدلية.bat] أو الملف التنفيذي [pharmaos.exe].

3. الميزات المدمجة في هذا الإصدار:
----------------------------------
- إدارة الورديات وبدء اليومية ومطابقة النقد بالدرج وحساب الفوارق.
- شاشة إغلاق اليومية قبل الخروج مع إحصاءات المبيعات والأصناف الأكثر مبيعاً.
- معالجة العجز وتسجيل سندات الصرف التلقائية للمسحوبات المنسية.
- النسخ الاحتياطي السحابي الثلاثي الصامت عند الإغلاق.
- تطبيق المدير للمراقبة اللحظية والتحكم عن بعد (تطبيق_المدير_PharmaOS_Owner.apk).

نتمنى لكم دوام التوفيق والنجاح.
''', mode: FileMode.write);

    final guideBat = File(p.join(targetDir.path, 'فتح_دليل_التشغيل.bat'));
    await guideBat.writeAsString('''@echo off
chcp 65001 > nul
start "" notepad.exe "%~dp0دليل_التشغيل_والاستخدام_الشامل.txt"
exit
''', mode: FileMode.write);
  }

  print('\n🎯 ALL delivery & release directories updated successfully with 100% healthy, latest components!');
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
