// نموذج بيانات التحديثات التلقائية - PharmaOS OTA Update Model
import 'dart:convert';

class AppUpdateInfo {
  final String version; // مثال: "1.1.0"
  final int buildNumber; // مثال: 2
  final String releaseDate; // مثال: "2026-09-10"
  final String downloadUrl; // رابط حزمة التحديث المباشر
  final String changelogArabic; // تفاصيل ومميزات الإصدار بالعربية
  final String? changelogEnglish;
  final String? sha256; // للتأكد من سلامة التنزيل
  final bool isMandatory; // هل التحديث إجباري؟
  final int packageSizeBytes; // حجم ملف التحديث بالبايت

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.downloadUrl,
    required this.changelogArabic,
    this.changelogEnglish,
    this.sha256,
    this.isMandatory = false,
    this.packageSizeBytes = 0,
  });

  factory AppUpdateInfo.fromMap(Map<String, dynamic> map) {
    return AppUpdateInfo(
      version: map['version'] ?? map['latest_version'] ?? '1.0.0',
      buildNumber: map['build_number'] ?? map['buildNumber'] ?? 1,
      releaseDate: map['release_date'] ?? map['releaseDate'] ?? '',
      downloadUrl: map['download_url'] ?? map['downloadUrl'] ?? '',
      changelogArabic: map['changelog_ar'] ?? map['changelog'] ?? 'تحسينات عامة وإضافة ميزات جديدة.',
      changelogEnglish: map['changelog_en'],
      sha256: map['sha256'],
      isMandatory: map['is_mandatory'] ?? false,
      packageSizeBytes: map['package_size_bytes'] ?? 0,
    );
  }

  factory AppUpdateInfo.fromJson(String source) => AppUpdateInfo.fromMap(json.decode(source));

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'build_number': buildNumber,
      'release_date': releaseDate,
      'download_url': downloadUrl,
      'changelog_ar': changelogArabic,
      'changelog_en': changelogEnglish,
      'sha256': sha256,
      'is_mandatory': isMandatory,
      'package_size_bytes': packageSizeBytes,
    };
  }

  String toJson() => json.encode(toMap());
}
