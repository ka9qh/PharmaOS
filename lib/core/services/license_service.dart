// خدمة إدارة التراخيص وتعدد الصيدليات والفروع - PharmaOS License & Multi-Tenant Service
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tenant_config.dart';

class LicenseService {
  static const String _storageKey = 'pharmaos_tenant_config_v1';
  static TenantConfig? _cachedConfig;

  /// الحصول على الإعدادات الحالية للصيدلية والفرع
  static Future<TenantConfig> getTenantConfig() async {
    if (_cachedConfig != null) return _cachedConfig!;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        _cachedConfig = TenantConfig.fromJson(jsonStr);
        return _cachedConfig!;
      } catch (_) {}
    }

    // الإعدادات الافتراضية لأول تشغيل
    final defaultDeviceId = _generateDeviceId();
    _cachedConfig = TenantConfig(
      pharmacyId: 'PHARM-${DateTime.now().year}-001',
      pharmacyName: 'صيدلية نموذجية',
      deviceId: defaultDeviceId,
      isActivated: true,
    );

    await saveTenantConfig(_cachedConfig!);
    return _cachedConfig!;
  }

  /// حفظ وتحديث بيانات الصيدلية أو الفرع
  static Future<void> saveTenantConfig(TenantConfig config) async {
    _cachedConfig = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, config.toJson());
  }

  /// التحقق من صلاحية الترخيص
  static Future<bool> isLicenseValid() async {
    final config = await getTenantConfig();
    if (!config.isActivated) return false;
    if (config.licenseExpiry == null) return true; // رخصة دائمة
    return DateTime.now().isBefore(config.licenseExpiry!);
  }

  /// توليد معرّف جهاز مميز مبني على معلومات بيئة التشغيل
  static String _generateDeviceId() {
    try {
      final host = Platform.localHostname;
      final os = Platform.operatingSystem;
      final raw = '$host-$os-pharmaos-pos';
      final hash = md5.convert(utf8.encode(raw)).toString().substring(0, 8).toUpperCase();
      return 'POS-$hash';
    } catch (_) {
      return 'POS-DEFAULT';
    }
  }

  /// تفعيل رخصة تجارية جديدة
  static Future<bool> activateLicense({
    required String pharmacyId,
    required String pharmacyName,
    required String licenseKey,
    String? branchId,
    String? branchName,
    DateTime? expiryDate,
  }) async {
    if (pharmacyId.trim().isEmpty || licenseKey.trim().isEmpty) return false;

    final current = await getTenantConfig();
    final updated = current.copyWith(
      pharmacyId: pharmacyId.trim(),
      pharmacyName: pharmacyName.trim().isNotEmpty ? pharmacyName.trim() : current.pharmacyName,
      licenseKey: licenseKey.trim(),
      branchId: branchId?.trim().isNotEmpty == true ? branchId!.trim() : current.branchId,
      branchName: branchName?.trim().isNotEmpty == true ? branchName!.trim() : current.branchName,
      licenseExpiry: expiryDate,
      isActivated: true,
    );

    await saveTenantConfig(updated);
    return true;
  }
}
