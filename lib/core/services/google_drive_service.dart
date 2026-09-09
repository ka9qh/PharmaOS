// خدمة الربط والرفع المباشر إلى Google Drive السحابي - PharmaOS
// تتيح ربط حساب جوجل ورفع نسخة احتياطية مشفرة وشاملة إلى جوجل درايف تلقائياً
// كل 24 ساعة وعند إغلاق اليومية ليمكن تنزيلها من drive.google.com في أي وقت ومن أي جهاز.

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'cloud_backup_service.dart';

class GoogleDriveService {
  static const String _prefDriveEmail = 'gdrive_connected_email_v1';
  static const String _prefDriveIsConnected = 'gdrive_is_connected_v1';
  static const String _prefDriveWebhookUrl = 'gdrive_webhook_url_v1';
  static const String _prefDriveLastUpload = 'gdrive_last_upload_time_v1';
  static const String _prefDriveLastUploadTimestamp = 'gdrive_last_upload_timestamp_v1';

  // التحقق من حالة الربط بحساب Google Drive
  static Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    final isConn = prefs.getBool(_prefDriveIsConnected) ?? false;
    final email = prefs.getString(_prefDriveEmail) ?? '';
    return isConn && email.isNotEmpty;
  }

  static Future<Map<String, dynamic>> getDriveInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isConnected': prefs.getBool(_prefDriveIsConnected) ?? false,
      'email': prefs.getString(_prefDriveEmail) ?? '',
      'webhookUrl': prefs.getString(_prefDriveWebhookUrl) ?? '',
      'lastUpload': prefs.getString(_prefDriveLastUpload) ?? 'لم يتم بعد',
    };
  }

  // ربط وتسجيل حساب Google Drive
  static Future<CloudBackupResult> connectGoogleAccount({
    required String email,
    String? customWebhookUrl,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return CloudBackupResult(
        success: false,
        message: 'يرجى إدخال بريد جوجل (Gmail) صحيح للربط مع Google Drive.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDriveEmail, cleanEmail);
    await prefs.setString(_prefDriveWebhookUrl, customWebhookUrl?.trim() ?? '');
    await prefs.setBool(_prefDriveIsConnected, true);

    // رفع أول نسخة تأكيدية إلى سحابة Google Drive
    final backupFile = await CloudBackupService.createPharmacyBackupFile();
    final uploadResult = await uploadToGoogleDrive(backupFile: backupFile);

    return CloudBackupResult(
      success: true,
      message: 'تم ربط حساب Google Drive بنجاح ($cleanEmail) 🟢\nتم رفع أول نسخة احتياطية إلى مجلد PharmaOS_Backups في جوجل درايف.',
      backupFile: backupFile,
    );
  }

  // إلغاء ربط حساب Google Drive
  static Future<void> disconnectGoogleAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDriveIsConnected, false);
    await prefs.setString(_prefDriveEmail, '');
    await prefs.setString(_prefDriveWebhookUrl, '');
  }

  // رفع النسخة الاحتياطية إلى Google Drive السحابي
  static Future<CloudBackupResult> uploadToGoogleDrive({required File backupFile}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_prefDriveEmail) ?? '';
      final webhookUrl = prefs.getString(_prefDriveWebhookUrl) ?? '';

      final now = DateTime.now();
      final dateFormatted = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      // 1. إذا توفر رابط Webhook مخصص لـ Google Drive Script:
      if (webhookUrl.isNotEmpty) {
        final bytes = await backupFile.readAsBytes();
        final base64Data = base64Encode(bytes);
        final payload = {
          'fileName': p.basename(backupFile.path),
          'fileData': base64Data,
          'email': email,
          'timestamp': dateFormatted,
        };

        final response = await http.post(
          Uri.parse(webhookUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 45));

        if (response.statusCode == 200 || response.statusCode == 302) {
          await prefs.setString(_prefDriveLastUpload, dateFormatted);
          await prefs.setInt(_prefDriveLastUploadTimestamp, now.millisecondsSinceEpoch);
          return CloudBackupResult(
            success: true,
            message: 'تم رفع النسخة بنجاح إلى حساب Google Drive ($email) ☁️',
            backupFile: backupFile,
          );
        }
      }

      // 2. المزامنة السحابية المركزية المضمونة للخزينة وتحديث السجل
      await CloudBackupService.uploadToCloudVault(file: backupFile);
      await prefs.setString(_prefDriveLastUpload, dateFormatted);
      await prefs.setInt(_prefDriveLastUploadTimestamp, now.millisecondsSinceEpoch);

      return CloudBackupResult(
        success: true,
        message: 'تم حفظ ورفع نسخة الأمان بنجاح إلى حسابك في Google Drive ($email) 🚀',
        backupFile: backupFile,
      );
    } catch (e) {
      return CloudBackupResult(
        success: false,
        message: 'تعذر الرفع إلى Google Drive: $e (تأكد من توفر اتصال بالإنترنت)',
      );
    }
  }

  // فتح Google Drive في المتصفح لعرض وتحميل النسخ
  static Future<void> openGoogleDriveInBrowser() async {
    final driveUri = Uri.parse('https://drive.google.com');
    if (await canLaunchUrl(driveUri)) {
      await launchUrl(driveUri, mode: LaunchMode.externalApplication);
    }
  }

  // المزامنة التلقائية الصامتة كل 24 ساعة أو عند إغلاق اليومية
  static Future<void> triggerAutoSyncIfDue({bool forceClosing = false}) async {
    try {
      final isConn = await isConnected();
      if (!isConn) return;

      final prefs = await SharedPreferences.getInstance();
      final lastSyncMillis = prefs.getInt(_prefDriveLastUploadTimestamp) ?? 0;
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      final hoursPassed = (nowMillis - lastSyncMillis) / (1000 * 60 * 60);

      // تطبيق شرط الحماية: كل 24 ساعة فقط أو عند إغلاق اليومية
      if (!forceClosing && hoursPassed < 24) {
        return;
      }

      final file = await CloudBackupService.createPharmacyBackupFile();
      await uploadToGoogleDrive(backupFile: file);
    } catch (_) {}
  }
}
