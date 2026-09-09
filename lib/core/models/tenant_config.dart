// نموذج تهيئة وتراخيص الصيدلية وتعدد الفروع - PharmaOS Multi-Tenant
import 'dart:convert';

class TenantConfig {
  final String pharmacyId; // كود الصيدلية الفريد (مثال: PHARM-1001)
  final String pharmacyName; // اسم الصيدلية
  final String licenseKey; // مفتاح الترخيص المشفر
  final String branchId; // كود الفرع (الافتراضي: 'main' أو '1')
  final String branchName; // اسم الفرع (مثال: الفرع الرئيسي)
  final String deviceId; // معرف نقطة البيع / اللابتوب (مثال: POS-01)
  final bool isCloudSyncEnabled; // هل تم تفعيل المزامنة السحابية للفروع؟
  final String cloudServerUrl; // رابط الخادم السحابي المشفر
  final DateTime? licenseExpiry; // تاريخ انتهاء الترخيص (null للرخصة الدائمة)
  final bool isActivated; // هل تم تفعيل النظام برخصة رسمية؟

  const TenantConfig({
    this.pharmacyId = 'PHARM-LOCAL-01',
    this.pharmacyName = 'صيدلية نموذجية',
    this.licenseKey = 'PHARMAOS-COMMERCIAL-LIFETIME',
    this.branchId = 'main',
    this.branchName = 'الفرع الرئيسي',
    this.deviceId = 'POS-01',
    this.isCloudSyncEnabled = false,
    this.cloudServerUrl = '',
    this.licenseExpiry,
    this.isActivated = true,
  });

  TenantConfig copyWith({
    String? pharmacyId,
    String? pharmacyName,
    String? licenseKey,
    String? branchId,
    String? branchName,
    String? deviceId,
    bool? isCloudSyncEnabled,
    String? cloudServerUrl,
    DateTime? licenseExpiry,
    bool? isActivated,
  }) {
    return TenantConfig(
      pharmacyId: pharmacyId ?? this.pharmacyId,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      licenseKey: licenseKey ?? this.licenseKey,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      deviceId: deviceId ?? this.deviceId,
      isCloudSyncEnabled: isCloudSyncEnabled ?? this.isCloudSyncEnabled,
      cloudServerUrl: cloudServerUrl ?? this.cloudServerUrl,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      isActivated: isActivated ?? this.isActivated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'licenseKey': licenseKey,
      'branchId': branchId,
      'branchName': branchName,
      'deviceId': deviceId,
      'isCloudSyncEnabled': isCloudSyncEnabled,
      'cloudServerUrl': cloudServerUrl,
      'licenseExpiry': licenseExpiry?.toIso8601String(),
      'isActivated': isActivated,
    };
  }

  factory TenantConfig.fromMap(Map<String, dynamic> map) {
    return TenantConfig(
      pharmacyId: map['pharmacyId'] ?? 'PHARM-LOCAL-01',
      pharmacyName: map['pharmacyName'] ?? 'صيدلية نموذجية',
      licenseKey: map['licenseKey'] ?? 'PHARMAOS-COMMERCIAL-LIFETIME',
      branchId: map['branchId'] ?? 'main',
      branchName: map['branchName'] ?? 'الفرع الرئيسي',
      deviceId: map['deviceId'] ?? 'POS-01',
      isCloudSyncEnabled: map['isCloudSyncEnabled'] ?? false,
      cloudServerUrl: map['cloudServerUrl'] ?? '',
      licenseExpiry: map['licenseExpiry'] != null ? DateTime.tryParse(map['licenseExpiry']) : null,
      isActivated: map['isActivated'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory TenantConfig.fromJson(String source) => TenantConfig.fromMap(json.decode(source));
}
