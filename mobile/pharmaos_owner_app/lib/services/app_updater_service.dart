// خدمة التحديثات التلقائية لتطبيق المدير من GitHub Releases - PharmaOS Owner App Updater
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OwnerAppUpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String downloadUrl;
  final List<String> changelogAr;
  final bool isCritical;

  const OwnerAppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.downloadUrl,
    required this.changelogAr,
    this.isCritical = false,
  });

  factory OwnerAppUpdateInfo.fromJson(Map<String, dynamic> json) {
    var rawChangelog = json['changelog_ar'] ?? json['changelog'] ?? [];
    List<String> logs = [];
    if (rawChangelog is List) {
      logs = rawChangelog.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawChangelog is String) {
      logs = rawChangelog
          .split('\n')
          .map((e) => e.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return OwnerAppUpdateInfo(
      version: json['version']?.toString() ?? json['latest_version']?.toString() ?? '1.0.0',
      buildNumber: int.tryParse(json['build_number']?.toString() ?? '1') ?? 1,
      releaseDate: json['release_date']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString() ??
          'https://github.com/ka9qh/PharmaOS/releases/latest',
      changelogAr: logs.isNotEmpty
          ? logs
          : [
              'تحسينات عامة في الأداء والسرعة',
              'تحديثات وميزات إدارية جديدة',
            ],
      isCritical: json['is_critical'] == true || json['is_mandatory'] == true,
    );
  }
}

class AppUpdaterService {
  // الإصدار الحالي لتطبيق المدير
  static const String currentVersion = '1.0.0';
  static const int currentBuildNumber = 1;

  // رابط ملف بيان التحديثات من GitHub
  static const String manifestUrl =
      'https://raw.githubusercontent.com/ka9qh/PharmaOS/main/releases/owner_app_version.json';

  /// فحص وجود تحديث جديد عبر GitHub Releases
  static Future<OwnerAppUpdateInfo?> checkForUpdates() async {
    try {
      final response = await http
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final updateInfo = OwnerAppUpdateInfo.fromJson(data);

        if (_isNewer(updateInfo.version, updateInfo.buildNumber)) {
          return updateInfo;
        }
      }
    } catch (e) {
      debugPrint('Error checking owner app updates: $e');
    }
    return null;
  }

  /// التحقق مما إذا كان الإصدار القادم أحدث من الإصدار الحالي
  static bool _isNewer(String serverVersion, int serverBuild) {
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

  /// إظهار نافذة التحديث الجذاب مع تفاصيل الإصدار والتغييرات وزر التنزيل
  static void showUpdateDialog(BuildContext context, OwnerAppUpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: !update.isCritical,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تحديث جديد متوفر 🚀',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'الإصدار v${update.version} (تاريخ: ${update.releaseDate.isNotEmpty ? update.releaseDate : "الآن"})',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إصدارك الحالي: v$currentVersion',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'الجديد: v${update.version}',
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'أبرز الإضافات والميزات في هذا التحديث:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ...update.changelogAr.map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log,
                            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (update.isCritical) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تحديث هام وإلزامي لضمان استقرار المزامنة مع الصيدلية.',
                            style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!update.isCritical)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تذكيري لاحقاً', style: TextStyle(color: Colors.grey)),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.download_for_offline_rounded, size: 20),
              label: const Text('تحديث وتنزيل APK الآن 📥', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(update.downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('رابط التحديث: ${update.downloadUrl}'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// إظهار رسالة تفيد بأن التطبيق محدث بالكامل
  static void showNoUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 28),
              ),
              const SizedBox(width: 10),
              const Text('التطبيق محدّث بالكامل', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أنت تستخدم أحدث إصدار من تطبيق المدير (v$currentVersion).',
                style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
              ),
              SizedBox(height: 8),
              Text(
                'جميع ميزات الرقابة اللحظية، وإدخال فواتير المشتريات، وجدول البدائل، والبث المباشر متزامنة وسليمة 100%.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }
}
