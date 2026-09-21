// خدمة إدارة التراخيص وتعدد الصيدليات والفروع - PharmaOS License & Multi-Tenant Service
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/tenant_config.dart';
import 'cloud_sync_service.dart';

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

  /// التحقق من صلاحية الترخيص (محلياً وسحابياً إذا أمكن)
  static Future<bool> isLicenseValid() async {
    final config = await getTenantConfig();
    if (!config.isActivated) return false;
    
    // فحص الإيقاف من الإدارة
    if (config.pausedByAdmin) return false;

    // فحص تاريخ الاشتراك المحلي
    if (config.subscriptionType == 'limited' && config.subscriptionEnd != null) {
      if (DateTime.now().isAfter(config.subscriptionEnd!)) {
        return false;
      }
    }
    
    // التحقق السحابي في الخلفية (اختياري، لا يوقف النظام إذا لم يكن هناك نت)
    _verifyLicenseCloudBackground(config);

    return true;
  }

  static Future<void> _verifyLicenseCloudBackground(TenantConfig config) async {
    try {
      final url = await CloudSyncService.getSupabaseUrl();
      final key = await CloudSyncService.getSupabaseAnonKey();
      
      final res = await http.get(
        Uri.parse('$url/rest/v1/pharmacies?license_key=eq.${config.licenseKey}&select=is_active,subscription_type,subscription_end,paused_by_admin'),
        headers: {
          'apikey': key,
          'Authorization': 'Bearer $key',
        },
      );
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        if (data.isNotEmpty) {
          final p = data.first;
          final bool paused = p['paused_by_admin'] == true || p['is_active'] == false;
          final subType = p['subscription_type'];
          final subEndStr = p['subscription_end'];
          
          final updated = config.copyWith(
            pausedByAdmin: paused,
            subscriptionType: subType,
            subscriptionEnd: subEndStr != null ? DateTime.parse(subEndStr) : null,
          );
          
          await saveTenantConfig(updated);
        }
      }
    } catch (_) {
      // تجاهل أخطاء الشبكة
    }
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

  /// تفعيل رخصة تجارية جديدة (يتطلب اتصال بالانترنت للتحقق من Supabase)
  static Future<bool> activateLicense({
    required String licenseKey,
    String? branchActivationKey,
  }) async {
    if (licenseKey.trim().isEmpty) return false;

    try {
      final url = await CloudSyncService.getSupabaseUrl();
      final key = await CloudSyncService.getSupabaseAnonKey();
      
      // 1. التحقق من الصيدلية
      final res = await http.get(
        Uri.parse('$url/rest/v1/pharmacies?license_key=eq.${licenseKey.trim()}&select=id,name,is_active,license_type,subscription_type,subscription_end,paused_by_admin'),
        headers: {
          'apikey': key,
          'Authorization': 'Bearer $key',
        },
      );
      
      if (res.statusCode != 200) return false;
      final data = json.decode(res.body) as List;
      if (data.isEmpty) return false; // الترخيص غير موجود
      
      final p = data.first;
      if (p['is_active'] == false || p['paused_by_admin'] == true) return false; // الحساب موقوف
      
      final String pId = p['id'].toString();
      final String pName = p['name'];
      final String lType = p['license_type'] ?? 'single';
      final String sType = p['subscription_type'] ?? 'lifetime';
      final String? sEndStr = p['subscription_end'];
      
      // 2. التحقق من الفرع إذا كان ترخيص متعدد الفروع
      String? bId;
      String? bName;
      
      if (lType == 'multi_branch') {
        if (branchActivationKey == null || branchActivationKey.isEmpty) return false; // مطلوب رمز فرع
        
        final bRes = await http.get(
          Uri.parse('$url/rest/v1/branches?branch_activation_key=eq.${branchActivationKey.trim()}&pharmacy_id=eq.$pId&select=id,name,is_active'),
          headers: {
            'apikey': key,
            'Authorization': 'Bearer $key',
          },
        );
        
        if (bRes.statusCode != 200) return false;
        final bData = json.decode(bRes.body) as List;
        if (bData.isEmpty || bData.first['is_active'] == false) return false; // فرع غير موجود أو موقوف
        
        bId = bData.first['id'].toString();
        bName = bData.first['name'];
      }

      // 3. تحديث البصمة للجهاز في Supabase (تسجيل الجهاز)
      final deviceId = _generateDeviceId();
      if (lType == 'single') {
        await http.patch(
          Uri.parse('$url/rest/v1/pharmacies?id=eq.$pId'),
          headers: {
            'apikey': key,
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: json.encode({'device_fingerprint': deviceId}),
        );
      } else if (bId != null) {
        await http.patch(
          Uri.parse('$url/rest/v1/branches?id=eq.$bId'),
          headers: {
            'apikey': key,
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: json.encode({'branch_device_fingerprint': deviceId}),
        );
      }

      // 4. حفظ محلياً
      final current = await getTenantConfig();
      final updated = current.copyWith(
        pharmacyId: pId,
        pharmacyName: pName,
        licenseKey: licenseKey.trim(),
        branchId: bId ?? current.branchId,
        branchName: bName ?? current.branchName,
        isActivated: true,
        deviceId: deviceId,
        licenseType: lType,
        subscriptionType: sType,
        subscriptionEnd: sEndStr != null ? DateTime.parse(sEndStr) : null,
        pausedByAdmin: false,
      );

      await saveTenantConfig(updated);
      return true;
      
    } catch (e) {
      return false;
    }
  }
}
