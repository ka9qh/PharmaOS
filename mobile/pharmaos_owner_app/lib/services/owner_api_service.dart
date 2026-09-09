// خدمة الاتصال السحابي متعددة الصيدليات لتطبيق المدير - PharmaOS Owner App
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class OwnerApiService {
  static const String _prefPharmacyId = 'owner_pharmacy_id_v1';
  static const String _prefPharmacyName = 'owner_pharmacy_name_v1';
  static const String _prefLicenseKey = 'owner_license_key_v1';
  static const String _prefManagerName = 'owner_manager_name_v1';
  static const String _prefSupabaseUrl = 'owner_supabase_url_v1';
  static const String _prefSupabaseKey = 'owner_supabase_key_v1';

  static Future<void> saveConfig(OwnerTenantConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefPharmacyId, config.pharmacyId);
    await prefs.setString(_prefPharmacyName, config.pharmacyName);
    await prefs.setString(_prefLicenseKey, config.licenseKey);
    await prefs.setString(_prefManagerName, config.managerName);
    await prefs.setString(_prefSupabaseUrl, config.supabaseUrl);
    await prefs.setString(_prefSupabaseKey, config.supabaseKey);
  }

  static Future<OwnerTenantConfig?> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final pharmacyId = prefs.getInt(_prefPharmacyId);
    if (pharmacyId == null) return null;

    return OwnerTenantConfig(
      pharmacyId: pharmacyId,
      pharmacyName: prefs.getString(_prefPharmacyName) ?? 'صيدليتي',
      licenseKey: prefs.getString(_prefLicenseKey) ?? '',
      managerName: prefs.getString(_prefManagerName) ?? 'المدير العام',
      supabaseUrl: prefs.getString(_prefSupabaseUrl) ?? 'https://bwgilcmzffcwdcxhfyfk.supabase.co',
      supabaseKey: prefs.getString(_prefSupabaseKey) ?? 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16',
    );
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Map<String, String> _headers(String apiKey) => {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  /// جلب فواتير المبيعات الخاصة بصيدلية المدير حصراً
  static Future<List<CloudSale>> fetchSales({int limit = 50}) async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      final url = '${config.supabaseUrl}/rest/v1/cloud_sales?pharmacy_id=eq.${config.pharmacyId}&order=created_at.desc&limit=$limit';
      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => CloudSale.fromJson(j)).toList();
        }
      }
    } catch (e) {
      debugPrint('OwnerApiService fetchSales error: $e');
    }
    return [];
  }

  /// جلب إغلاقات الصناديق اليومية Z-Reports
  static Future<List<CloudDayClosing>> fetchDayClosings({int limit = 30}) async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      final url = '${config.supabaseUrl}/rest/v1/cloud_day_closings?pharmacy_id=eq.${config.pharmacyId}&order=created_at.desc&limit=$limit';
      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => CloudDayClosing.fromJson(j)).toList();
        }
      }
    } catch (e) {
      debugPrint('OwnerApiService fetchDayClosings error: $e');
    }
    return [];
  }

  /// جلب استشارات الروشتات الفورية للفرع والصيدلية
  static Future<List<OwnerTeleConsultation>> fetchTeleConsultations({String? status}) async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      var url = '${config.supabaseUrl}/rest/v1/cloud_tele_consultations?pharmacy_id=eq.${config.pharmacyId}';
      if (status != null && status.isNotEmpty) {
        url += '&status=eq.$status';
      }
      url += '&order=created_at.desc&limit=50';

      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => OwnerTeleConsultation.fromJson(j)).toList();
        }
      }
    } catch (e) {
      debugPrint('OwnerApiService fetchTeleConsultations error: $e');
    }
    return [];
  }

  /// رد المدير على استشارة أو روشتة
  static Future<bool> replyConsultation({
    required int consultationId,
    required String reply,
    String? suggestedMedicines,
    String? voiceBase64,
  }) async {
    final config = await getConfig();
    if (config == null) return false;

    try {
      final payload = {
        'manager_reply': reply,
        'suggested_medicines': suggestedMedicines,
        if (voiceBase64 != null) 'voice_base64': voiceBase64,
        'manager_name': config.managerName,
        'status': 'answered',
        'answered_at': DateTime.now().toIso8601String(),
      };

      final response = await http
          .patch(
            Uri.parse('${config.supabaseUrl}/rest/v1/cloud_tele_consultations?id=eq.$consultationId'),
            headers: _headers(config.supabaseKey),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('OwnerApiService replyConsultation error: $e');
      return false;
    }
  }

  /// جلب الأدوية والمخزون
  static Future<List<CloudMedicine>> searchMedicines(String query) async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      final q = Uri.encodeComponent(query.trim());
      final url = '${config.supabaseUrl}/rest/v1/cloud_medicines?pharmacy_id=eq.${config.pharmacyId}&name_ar=ilike.*$q*&limit=30';
      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => CloudMedicine.fromJson(j)).toList();
        }
      }
    } catch (e) {
      debugPrint('OwnerApiService searchMedicines error: $e');
    }
    return [];
  }
}
