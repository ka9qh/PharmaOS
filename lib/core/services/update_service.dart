// خدمة التحديثات التلقائية عن بعد - PharmaOS OTA Update Service
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/app_update_info.dart';
import 'backup_service.dart';

class UpdateService {
  // الإصدار الحالي للتطبيق
  static const String currentVersion = '1.0.1';
  static const int currentBuildNumber = 1;

  // الرابط الافتراضي للتحقق من التحديثات من GitHub Releases أو السيرفر المباشر
  static const String defaultUpdateManifestUrl =
      'https://raw.githubusercontent.com/ka9qh/PharmaOS/main/releases/version.json';

  /// فحص وجود تحديثات جديدة عبر الإنترنت
  static Future<AppUpdateInfo?> checkForUpdates({String? customManifestUrl}) async {
    final url = customManifestUrl ?? defaultUpdateManifestUrl;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final updateInfo = AppUpdateInfo.fromJson(responseBody);

        if (_isNewerVersion(updateInfo.version, updateInfo.buildNumber)) {
          return updateInfo;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Update check error: $e');
      return null;
    }
  }

  /// مقارنة أرقام الإصدارات لتحديد ما إذا كان الإصدار القادم أحدث
  static bool _isNewerVersion(String serverVersion, int serverBuild) {
    if (serverBuild > currentBuildNumber) return true;

    final currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final serverParts = serverVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final cur = i < currentParts.length ? currentParts[i] : 0;
      final srv = i < serverParts.length ? serverParts[i] : 0;
      if (srv > cur) return true;
      if (srv < cur) return false;
    }
    return false;
  }

  /// تنزيل حزمة التحديث مع أخذ نسخة احتياطية إجبارية وفورية من قاعدة البيانات
  static Future<File?> downloadUpdatePackage(
    AppUpdateInfo update, {
    Function(double progress)? onProgress,
  }) async {
    try {
      // 1. أخذ نسخة احتياطية للأمان التام قبل لمس أي ملف
      await _createSafetyBackup();

      final tempDir = await getTemporaryDirectory();
      final updateDir = Directory(p.join(tempDir.path, 'pharmaos_update'));
      if (!await updateDir.exists()) {
        await updateDir.create(recursive: true);
      }

      final zipFile = File(p.join(updateDir.path, 'update.zip'));
      if (await zipFile.exists()) {
        await zipFile.delete();
      }

      final client = HttpClient();
      final uri = Uri.parse(update.downloadUrl);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        return null;
      }

      final contentLength = response.contentLength;
      int downloadedBytes = 0;

      final sink = zipFile.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(downloadedBytes / contentLength);
        }
      }
      await sink.flush();
      await sink.close();

      return zipFile;
    } catch (e) {
      debugPrint('Error downloading update package: $e');
      return null;
    }
  }

  /// إنشاء نسخة احتياطية فورية لقاعدة البيانات قبل التحديث
  static Future<void> _createSafetyBackup() async {
    try {
      final appDataDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDataDir.path, 'PharmaOS_Backups', 'pre_update'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final dbFile = File('C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db');
      if (await dbFile.exists()) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        final targetBackup = File(p.join(backupDir.path, 'backup_before_update_$timestamp.db'));
        await dbFile.copy(targetBackup.path);
        debugPrint('Safety backup created at: ${targetBackup.path}');
      }
    } catch (e) {
      debugPrint('Safety backup error: $e');
    }
  }

  /// استبدال ملفات البرنامج التلقائي وإعادة التشغيل (Zero-Friction In-Place Update)
  static Future<bool> applyUpdateAndRestart(File zipFile) async {
    try {
      final appDir = Directory.current.path;
      final scriptFile = File(p.join(appDir, 'pharmaos_updater.bat'));

      final zipPath = zipFile.path;
      final exePath = p.join(appDir, 'pharmaos.exe');

      // إنشاء سكريبت التحديث الذاتي السريع
      final scriptContent = '''@echo off
chcp 65001 > nul
title PharmaOS Auto Updater
echo =========================================================
echo جاري تحديث نظام PharmaOS وتثبيت الميزات الجديدة...
echo =========================================================
timeout /t 2 /nobreak > nul

powershell -ExecutionPolicy Bypass -NoProfile -Command "Expand-Archive -Path '$zipPath' -DestinationPath '$appDir' -Force"

if exist "$exePath" (
    echo تم التحديث بنجاح! جاري إطلاق النظام...
    start "" "$exePath"
)
exit
''';

      await scriptFile.writeAsString(scriptContent);

      // تشغيل سكريبت التحديث والخروج من التطبيق فوراً
      await Process.start(
        'cmd.exe',
        ['/c', scriptFile.path],
        mode: ProcessStartMode.detached,
      );

      // إغلاق التطبيق الحالي بسلاسة ليتمكن السكريبت من استبدال الملفات
      exit(0);
    } catch (e) {
      debugPrint('Error applying update: $e');
      return false;
    }
  }
}
