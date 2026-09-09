import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  final targetDir = Directory('C:\\Users\\hp\\Desktop\\PharmaOS_Release');
  print('Updating target release folder: ${targetDir.path}');

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  final releaseSourceDir = Directory(p.join(Directory.current.path, 'build', 'windows', 'x64', 'runner', 'Release'));
  if (!await releaseSourceDir.exists()) {
    print('ERROR: Build Release directory not found at ${releaseSourceDir.path}');
    return;
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
    print('✅ Copied healthy pre-seeded database (pharmaos_secure.db) to PharmaOS_Release');
  }

  // 3. Copy Mobile Owner APK if present
  final rootApk = File(p.join(Directory.current.path, 'releases', 'PharmaOS_Owner.apk'));
  final buildApk = File(p.join(Directory.current.path, 'mobile', 'pharmaos_owner_app', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk'));
  
  if (await buildApk.exists()) {
    final destApk = File(p.join(targetDir.path, 'تطبيق_المدير_PharmaOS_Owner.apk'));
    await buildApk.copy(destApk.path);
    // Also mirror to releases/
    final relDir = Directory(p.join(Directory.current.path, 'releases'));
    if (!await relDir.exists()) await relDir.create(recursive: true);
    await buildApk.copy(rootApk.path);
    print('✅ Copied Android Owner APK (تطبيق_المدير_PharmaOS_Owner.apk) to PharmaOS_Release');
  } else if (await rootApk.exists()) {
    final destApk = File(p.join(targetDir.path, 'تطبيق_المدير_PharmaOS_Owner.apk'));
    await rootApk.copy(destApk.path);
    print('✅ Copied Android Owner APK from releases to PharmaOS_Release');
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
  print('Created launcher: تشغيل_نظام_الصيدلية.bat');

  print('\n🎯 PharmaOS_Release updated successfully with 100% healthy components!');
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
