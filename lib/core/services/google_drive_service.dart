// خدمة الربط والرفع المباشر إلى Google Drive السحابي عبر OAuth2 الرسمي - PharmaOS
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'cloud_backup_service.dart';

class GoogleDriveService {
  static const String _prefDriveEmail = 'gdrive_connected_email_v1';
  static const String _prefDriveIsConnected = 'gdrive_is_connected_v1';
  static const String _prefDriveLastUpload = 'gdrive_last_upload_time_v1';
  static const String _prefDriveLastUploadTimestamp = 'gdrive_last_upload_timestamp_v1';
  static const String _prefDriveToken = 'gdrive_auth_token_v1';

  // ملاحظة: يجب استبدال هذا الـ Client ID الخاص بـ GCP الخاص بك.
  static final _clientId = ClientId(
    'YOUR_GOOGLE_CLOUD_CLIENT_ID.apps.googleusercontent.com', 
    'YOUR_GOOGLE_CLOUD_CLIENT_SECRET'
  );

  static const _scopes = [drive.DriveApi.driveFileScope];

  // التحقق من حالة الربط بحساب Google Drive
  static Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    final isConn = prefs.getBool(_prefDriveIsConnected) ?? false;
    final token = prefs.getString(_prefDriveToken);
    return isConn && token != null && token.isNotEmpty;
  }

  static Future<Map<String, dynamic>> getDriveInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isConnected': prefs.getBool(_prefDriveIsConnected) ?? false,
      'email': prefs.getString(_prefDriveEmail) ?? 'تم الربط رسمياً',
      'lastUpload': prefs.getString(_prefDriveLastUpload) ?? 'لم يتم بعد',
    };
  }

  static Future<AccessCredentials?> _getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenJson = prefs.getString(_prefDriveToken);
    if (tokenJson == null) return null;
    try {
      final map = jsonDecode(tokenJson);
      return AccessCredentials.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<AuthClient?> _getAuthenticatedClient() async {
    final creds = await _getSavedCredentials();
    if (creds == null) return null;

    try {
      final client = autoRefreshingClient(_clientId, creds, http.Client());
      return client;
    } catch (e) {
      return null;
    }
  }

  // ربط وتسجيل حساب Google Drive عبر OAuth2
  static Future<CloudBackupResult> connectGoogleAccount({
    required String email, // Email parameter kept for compatibility, but actual auth uses OAuth
  }) async {
    try {
      final client = await clientViaUserConsent(_clientId, _scopes, (url) async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          debugPrint('يرجى زيارة الرابط التالي للسماح بالوصول: $url');
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDriveToken, jsonEncode(client.credentials.toJson()));
      await prefs.setBool(_prefDriveIsConnected, true);
      await prefs.setString(_prefDriveEmail, email.isNotEmpty ? email : 'تم الربط');

      final backupFile = await CloudBackupService.createPharmacyBackupFile();
      await uploadToGoogleDrive(backupFile: backupFile);

      return CloudBackupResult(
        success: true,
        message: 'تم ربط حساب Google Drive بنجاح عبر OAuth2 الرسمي 🟢\nتم رفع أول نسخة احتياطية.',
        backupFile: backupFile,
      );
    } catch (e) {
      return CloudBackupResult(
        success: false,
        message: 'فشل عملية المصادقة: $e',
      );
    }
  }

  // إلغاء ربط حساب Google Drive
  static Future<void> disconnectGoogleAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDriveIsConnected, false);
    await prefs.setString(_prefDriveEmail, '');
    await prefs.setString(_prefDriveToken, '');
  }

  // رفع النسخة الاحتياطية إلى Google Drive السحابي
  static Future<CloudBackupResult> uploadToGoogleDrive({required File backupFile}) async {
    try {
      final client = await _getAuthenticatedClient();
      if (client == null) {
        throw Exception('غير مصرح. يرجى إعادة تسجيل الدخول.');
      }

      final driveApi = drive.DriveApi(client);
      
      final now = DateTime.now();
      final dateFormatted = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final fileToUpload = drive.File();
      fileToUpload.name = p.basename(backupFile.path);

      final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());
      
      await driveApi.files.create(fileToUpload, uploadMedia: media);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDriveLastUpload, dateFormatted);
      await prefs.setInt(_prefDriveLastUploadTimestamp, now.millisecondsSinceEpoch);

      return CloudBackupResult(
        success: true,
        message: 'تم رفع النسخة بنجاح إلى حساب Google Drive عبر OAuth2 ☁️',
        backupFile: backupFile,
      );
    } catch (e) {
      return CloudBackupResult(
        success: false,
        message: 'تعذر الرفع إلى Google Drive: $e',
      );
    }
  }

  static Future<void> openGoogleDriveInBrowser() async {
    final driveUri = Uri.parse('https://drive.google.com');
    if (await canLaunchUrl(driveUri)) {
      await launchUrl(driveUri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> triggerAutoSyncIfDue({bool forceClosing = false}) async {
    try {
      final isConn = await isConnected();
      if (!isConn) return;

      final prefs = await SharedPreferences.getInstance();
      final lastSyncMillis = prefs.getInt(_prefDriveLastUploadTimestamp) ?? 0;
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      final hoursPassed = (nowMillis - lastSyncMillis) / (1000 * 60 * 60);

      if (!forceClosing && hoursPassed < 24) {
        return;
      }

      final file = await CloudBackupService.createPharmacyBackupFile();
      await uploadToGoogleDrive(backupFile: file);
    } catch (_) {}
  }
}
