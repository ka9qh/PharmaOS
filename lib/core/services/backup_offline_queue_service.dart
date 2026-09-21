import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'cloud_sync_service.dart';
import 'license_service.dart';
import 'package:flutter/foundation.dart';

class PendingBackup {
  final String filePath;
  final String fileHash;
  final String fileName;
  final int fileSizeBytes;
  final String triggerReason;
  
  PendingBackup({
    required this.filePath,
    required this.fileHash,
    required this.fileName,
    required this.fileSizeBytes,
    required this.triggerReason,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileHash': fileHash,
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
        'triggerReason': triggerReason,
      };

  factory PendingBackup.fromJson(Map<String, dynamic> json) => PendingBackup(
        filePath: json['filePath'],
        fileHash: json['fileHash'],
        fileName: json['fileName'],
        fileSizeBytes: json['fileSizeBytes'],
        triggerReason: json['triggerReason'],
      );
}

class BackupOfflineQueueService {
  static const String _queueKey = 'pharmaos_pending_backups_queue_v1';

  static Future<void> enqueueBackup(PendingBackup backup) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_queueKey) ?? [];
    
    // منع التكرار بناءً على الـ Hash
    final existing = rawList.map((e) => jsonDecode(e)).where((e) => e['fileHash'] == backup.fileHash).toList();
    if (existing.isEmpty) {
      rawList.add(jsonEncode(backup.toJson()));
      await prefs.setStringList(_queueKey, rawList);
    }
  }

  static Future<List<PendingBackup>> getPendingBackups() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_queueKey) ?? [];
    return rawList.map((e) => PendingBackup.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> removeBackup(String fileHash) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_queueKey) ?? [];
    
    rawList.removeWhere((e) {
      final map = jsonDecode(e);
      return map['fileHash'] == fileHash;
    });
    
    await prefs.setStringList(_queueKey, rawList);
  }

  static Future<void> syncOfflineQueue() async {
    final pendingBackups = await getPendingBackups();
    if (pendingBackups.isEmpty) return;

    debugPrint('🔄 يوجد ${pendingBackups.length} نسخ احتياطية معلقة للرفع السحابي');

    try {
      final config = await LicenseService.getTenantConfig();
      final pharmacyId = config.pharmacyId;
      final url = await CloudSyncService.getSupabaseUrl();
      final key = await CloudSyncService.getSupabaseAnonKey();

      for (final backup in pendingBackups) {
        final file = File(backup.filePath);
        if (!await file.exists()) {
          // الملف تم حذفه محلياً، نزيله من الطابور
          await removeBackup(backup.fileHash);
          continue;
        }

        final bytes = await file.readAsBytes();
        final actualHash = md5.convert(bytes).toString();

        // الرفع لـ Storage
        final storageRes = await http.post(
          Uri.parse('$url/storage/v1/object/backups/$pharmacyId/${backup.fileName}'),
          headers: {
            'apikey': key,
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        );

        if (storageRes.statusCode == 200 || storageRes.statusCode == 409) {
          // تسجيل في قاعدة البيانات
          final recordRes = await http.post(
            Uri.parse('$url/rest/v1/cloud_backups'),
            headers: {
              'apikey': key,
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'pharmacy_id': pharmacyId,
              'file_name': backup.fileName,
              'file_hash': actualHash,
              'file_size_bytes': backup.fileSizeBytes,
              'trigger_reason': backup.triggerReason + ' (رفع متأخر)',
              'is_uploaded_supabase': true,
            }),
          );

          if (recordRes.statusCode == 201 || recordRes.statusCode == 409) {
             debugPrint('✅ تم رفع النسخة الاحتياطية المتأخرة: ${backup.fileName}');
             await removeBackup(backup.fileHash);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ فشل مزامنة الطابور السحابي للنسخ: $e');
    }
  }
}
