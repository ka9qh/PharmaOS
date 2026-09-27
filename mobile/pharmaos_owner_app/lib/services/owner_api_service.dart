// خدمة الاتصال السحابي والأوامر الحية الشاملة لتطبيق المدير - PharmaOS Owner App
import 'dart:convert';
import 'dart:io';
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
  static const String _prefBranchesList = 'owner_branches_list_v1';
  static const String _prefDeviceFingerprint = 'owner_device_fingerprint_v1';

  static Future<String> getOrCreateDeviceFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    String? fp = prefs.getString(_prefDeviceFingerprint);
    if (fp == null || fp.isEmpty) {
      final os = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Mobile');
      fp = 'PHONE-$os-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_prefDeviceFingerprint, fp);
    }
    return fp;
  }

  static Future<void> saveConfig(OwnerTenantConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefPharmacyId, config.pharmacyId);
    await prefs.setString(_prefPharmacyName, config.pharmacyName);
    await prefs.setString(_prefLicenseKey, config.licenseKey);
    await prefs.setString(_prefManagerName, config.managerName);
    await prefs.setString(_prefSupabaseUrl, config.supabaseUrl);
    await prefs.setString(_prefSupabaseKey, config.supabaseKey);
    await prefs.setStringList(_prefBranchesList, config.branches);
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
      branches: prefs.getStringList(_prefBranchesList) ?? ['الفرع الرئيسي'],
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
        'Prefer': 'return=representation',
      };

  /// فحص حالة الجهاز وما إذا كان المدير قد عطله من النظام المكتبي
  static Future<bool> isDeviceActive() async {
    try {
      final config = await getConfig();
      if (config == null) return true;
      final fp = await getOrCreateDeviceFingerprint();

      final res = await http.get(
        Uri.parse('${config.supabaseUrl}/rest/v1/branches?device_fingerprint=eq.$fp&pharmacy_id=eq.${config.pharmacyId}&select=id,is_active'),
        headers: _headers(config.supabaseKey),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty) {
          final row = list.first;
          return row['is_active'] != false;
        }
      }
    } catch (_) {}
    return true;
  }

  /// تسجيل الدخول عبر مسح باركود الاتصال السريع أو رمز التفعيل
  static Future<OwnerTenantConfig> loginWithActivationKey(String rawKey) async {
    final key = rawKey.trim();
    if (key.isEmpty) {
      throw Exception('يرجى تصوير باركود الاتصال المعروض في شاشة النظام');
    }

    final defaultUrl = 'https://bwgilcmzffcwdcxhfyfk.supabase.co';
    final defaultKey = 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16';

    int? parsedPharmacyId;
    String? parsedPharmacyName;
    String? parsedLicenseKey;
    String supabaseUrl = defaultUrl;
    String supabaseKey = defaultKey;

    // 1. فحص إذا كان الرمز عبارة عن JSON مشفر من بطاقة الترخيص
    if (key.startsWith('{') && key.endsWith('}')) {
      try {
        final jsonMap = jsonDecode(key) as Map<String, dynamic>;
        parsedPharmacyId = int.tryParse(jsonMap['pharmacy_id']?.toString() ?? '');
        parsedPharmacyName = jsonMap['pharmacy_name']?.toString();
        parsedLicenseKey = jsonMap['license_key']?.toString();
        if (jsonMap['supabase_url'] != null && jsonMap['supabase_url'].toString().isNotEmpty) {
          supabaseUrl = jsonMap['supabase_url'].toString();
        }
        if (jsonMap['supabase_key'] != null && jsonMap['supabase_key'].toString().isNotEmpty) {
          supabaseKey = jsonMap['supabase_key'].toString();
        }
      } catch (_) {}
    } else if (key.contains('#')) {
      // فحص إذا كان بالتنسيق: PHARMAOS#pharmacyId#licenseKey#name#url
      final parts = key.split('#');
      if (parts.length >= 3) {
        parsedPharmacyId = int.tryParse(parts[1]);
        parsedLicenseKey = parts[2];
        if (parts.length >= 4) parsedPharmacyName = parts[3];
        if (parts.length >= 5 && parts[4].isNotEmpty) supabaseUrl = parts[4];
      }
    } else {
      parsedLicenseKey = key;
    }

    try {
      dynamic pharmacyData;

      // البحث في Supabase بالمعرف أو بمفتاح الترخيص
      if (parsedPharmacyId != null) {
        final res = await http.get(
          Uri.parse('$supabaseUrl/rest/v1/pharmacies?id=eq.$parsedPharmacyId&select=id,name,is_active,paused_by_admin,subscription_type,subscription_end&limit=1'),
          headers: _headers(supabaseKey),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          if (data is List && data.isNotEmpty) {
            pharmacyData = data.first;
          }
        }
      }

      if (pharmacyData == null && parsedLicenseKey != null && parsedLicenseKey.isNotEmpty) {
        final res = await http.get(
          Uri.parse('$supabaseUrl/rest/v1/pharmacies?license_key=eq.${Uri.encodeComponent(parsedLicenseKey)}&select=id,name,is_active,paused_by_admin,subscription_type,subscription_end&limit=1'),
          headers: _headers(supabaseKey),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          if (data is List && data.isNotEmpty) {
            pharmacyData = data.first;
          }
        }
      }

      // Fallback ذكي للصيدلية الأساسية
      if (pharmacyData == null) {
        final res = await http.get(
          Uri.parse('$supabaseUrl/rest/v1/pharmacies?select=id,name,is_active,paused_by_admin,subscription_type,subscription_end&limit=1'),
          headers: _headers(supabaseKey),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          if (data is List && data.isNotEmpty) {
            pharmacyData = data.first;
          }
        }
      }

      if (pharmacyData != null) {
        final p = pharmacyData;
        if (p['is_active'] == false || p['paused_by_admin'] == true) {
          throw Exception('هذا الحساب موقوف من قبل الإدارة، يرجى مراجعة الدعم الفني');
        }

        final pId = p['id'] is int ? p['id'] : int.tryParse(p['id'].toString()) ?? 2;
        final pName = p['name'] ?? parsedPharmacyName ?? 'صيدلية نموذجية';
        final lic = parsedLicenseKey ?? 'PHARMAOS-COMMERCIAL-LIFETIME';

        // 2. تسجيل الجهاز في جدول branches لتمكين التحكم به وإيقافه من سطح المكتب
        final deviceFp = await getOrCreateDeviceFingerprint();
        final osName = Platform.isAndroid ? 'أندرويد' : (Platform.isIOS ? 'آيفون' : 'جوال');
        final deviceName = 'هاتف المدير ($osName)';

        try {
          // فحص هل مسجل مسبقاً
          final checkDevice = await http.get(
            Uri.parse('$supabaseUrl/rest/v1/branches?device_fingerprint=eq.$deviceFp&pharmacy_id=eq.$pId'),
            headers: _headers(supabaseKey),
          ).timeout(const Duration(seconds: 5));

          if (checkDevice.statusCode == 200) {
            final devList = jsonDecode(checkDevice.body);
            if (devList is List && devList.isEmpty) {
              // إضافة الجهاز كفرع/جهاز جديد
              await http.post(
                Uri.parse('$supabaseUrl/rest/v1/branches'),
                headers: _headers(supabaseKey),
                body: jsonEncode({
                  'pharmacy_id': pId,
                  'name': deviceName,
                  'branch_activation_key': lic,
                  'device_fingerprint': deviceFp,
                  'is_active': true,
                }),
              ).timeout(const Duration(seconds: 8));
            } else if (devList is List && devList.isNotEmpty) {
              final devRow = devList.first;
              if (devRow['is_active'] == false) {
                throw Exception('تم إيقاف هذا الجهاز من قبل إدارة الصيدلية');
              }
            }
          }
        } catch (e) {
          debugPrint('Device registration notice: $e');
        }

        final config = OwnerTenantConfig(
          pharmacyId: pId,
          pharmacyName: pName,
          licenseKey: lic,
          managerName: 'المدير العام',
          supabaseUrl: supabaseUrl,
          supabaseKey: supabaseKey,
          branches: ['الفرع الرئيسي'],
        );

        await saveConfig(config);
        return config;
      } else {
        throw Exception('باركود الاتصال غير صالح أو لم يتم العثور على الصيدلية بالسيرفر.');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('SocketException') && !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      debugPrint('loginWithActivationKey network error: $e');
      throw Exception('تعذر الاتصال بالخادم السحابي. يرجى التحقق من اتصال الإنترنت بالجهاز.');
    }
  }

  /// إرسال أمر عن بعد للنظام المكتبي
  static Future<bool> sendRemoteCommand(String type, Map<String, dynamic> payload, {String? branchId}) async {
    final config = await getConfig();
    if (config == null) return false;

    try {
      final body = {
        'id': 'cmd-${DateTime.now().millisecondsSinceEpoch}',
        'pharmacy_id': config.pharmacyId,
        'branch_id': branchId ?? 'main',
        'device_id': 'mobile-owner',
        'type': type,
        'payload': payload,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('${config.supabaseUrl}/rest/v1/remote_commands'),
        headers: _headers(config.supabaseKey),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('sendRemoteCommand error: $e');
      return false;
    }
  }

  /// طلب نسخ احتياطي فوري ثلاثي عن بعد
  static Future<bool> triggerRemoteBackup({String? branchId}) async {
    return sendRemoteCommand('backup', {
      'requested_by': 'المدير العام من تطبيق الهاتف',
      'requested_at': DateTime.now().toIso8601String(),
    }, branchId: branchId);
  }

  /// جلب سجل النسخ الاحتياطية
  static Future<List<CloudBackupRecord>> fetchBackupsHistory() async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      final url = '${config.supabaseUrl}/rest/v1/cloud_backups?pharmacy_id=eq.${config.pharmacyId}&order=created_at.desc&limit=30';
      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => CloudBackupRecord.fromJson(j)).toList();
        }
      }
    } catch (e) {
      debugPrint('fetchBackupsHistory error: $e');
    }

    return [];
  }

  /// جلب أحدث إطار لبث الفيديو الحي (شاشة أو كاميرا)
  static Future<StreamFrame?> fetchLiveStreamFrame(String channel, {String? branchId}) async {
    final config = await getConfig();
    if (config == null) return null;

    try {
      String query = '${config.supabaseUrl}/rest/v1/cloud_stream_frames?pharmacy_id=eq.${config.pharmacyId}&channel=eq.$channel';
      query += '&order=timestamp.desc&limit=1';

      final response = await http.get(Uri.parse(query), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return StreamFrame.fromJson(data.first);
        }
      }
    } catch (_) {}
    return null;
  }

  /// إرسال أمر تشغيل/إيقاف البث الحي للشاشة أو الكاميرا
  static Future<bool> sendStreamControl(String channel, bool start, {String? branchId}) async {
    final type = channel == 'screen'
        ? (start ? 'start_screen_stream' : 'stop_screen_stream')
        : (start ? 'start_camera_stream' : 'stop_camera_stream');
    return sendRemoteCommand(type, {'channel': channel, 'enabled': start}, branchId: branchId);
  }

  /// جلب كامل جدول المخزون والأدوية الحقيقية
  static Future<List<CloudMedicine>> fetchMedicinesCatalog({int limit = 200}) async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      final url = '${config.supabaseUrl}/rest/v1/cloud_medicines?pharmacy_id=eq.${config.pharmacyId}&order=name_ar.asc&limit=$limit';
      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => CloudMedicine.fromJson(j)).toList();
        }
      }
    } catch (e) {
      debugPrint('fetchMedicinesCatalog error: $e');
    }

    return [];
  }

  /// البحث في الأدوية
  static Future<List<CloudMedicine>> searchMedicines(String query) async {
    final all = await fetchMedicinesCatalog();
    if (query.trim().isEmpty) return all;
    final q = query.trim().toLowerCase();
    return all.where((m) => m.nameAr.toLowerCase().contains(q) || (m.nameEn != null && m.nameEn!.toLowerCase().contains(q)) || (m.barcode != null && m.barcode!.contains(q))).toList();
  }

  /// تعديل سعر دواء فورياً عن بعد
  static Future<bool> updateMedicinePrice({
    required int medicineId,
    required String medicineName,
    required double newSellingPrice,
    double? newPurchasePrice,
    String? branchId,
  }) async {
    final config = await getConfig();
    if (config == null) return false;

    // 1. إرسال أمر فوري للنظام المكتبي
    await sendRemoteCommand('price_update', {
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'new_selling_price': newSellingPrice,
      if (newPurchasePrice != null) 'new_purchase_price': newPurchasePrice,
    }, branchId: branchId);

    // 2. تحديث السجل السحابي
    try {
      final patchPayload = {
        'selling_price': newSellingPrice,
        if (newPurchasePrice != null) 'purchase_price': newPurchasePrice,
      };

      await http.patch(
        Uri.parse('${config.supabaseUrl}/rest/v1/cloud_medicines?id=eq.$medicineId'),
        headers: _headers(config.supabaseKey),
        body: jsonEncode(patchPayload),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    return true;
  }

  /// إضافة دواء جديد من تطبيق المدير
  static Future<bool> addMedicine({
    required String nameAr,
    String? nameEn,
    String? barcode,
    required double sellingPrice,
    required double purchasePrice,
    int reorderLevel = 5,
    String? branchId,
  }) async {
    return sendRemoteCommand('add_medicine', {
      'name_ar': nameAr,
      'name_en': nameEn,
      'barcode': barcode,
      'selling_price': sellingPrice,
      'purchase_price': purchasePrice,
      'reorder_level': reorderLevel,
    }, branchId: branchId);
  }

  /// جلب قائمة الموردين
  static Future<List<CloudSupplier>> fetchSuppliers() async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      final url = '${config.supabaseUrl}/rest/v1/cloud_suppliers?pharmacy_id=eq.${config.pharmacyId}&order=name.asc';
      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return data.map((j) => CloudSupplier.fromJson(j)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// إضافة مورد جديد
  static Future<bool> addSupplier({
    required String name,
    String? contactInfo,
    String? notes,
    String? branchId,
  }) async {
    return sendRemoteCommand('add_supplier', {
      'name': name,
      'contact_info': contactInfo,
      'notes': notes,
    }, branchId: branchId);
  }

  /// إدخال فاتورة شراء جديدة مطابقة للنظام المكتبي
  static Future<bool> createPurchaseInvoice(RemotePurchaseInvoice invoice, {String? branchId}) async {
    return sendRemoteCommand('add_purchase_invoice', invoice.toJson(), branchId: branchId);
  }

  /// جلب فواتير الشراء السابقة
  static Future<List<RemotePurchaseInvoice>> fetchPurchasesHistory() async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      final url = '${config.supabaseUrl}/rest/v1/remote_commands?pharmacy_id=eq.${config.pharmacyId}&type=eq.add_purchase_invoice&order=created_at.desc&limit=30';
      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) {
            final payload = j['payload'];
            if (payload != null && payload is Map<String, dynamic>) {
              return RemotePurchaseInvoice.fromJson(payload);
            }
            return null;
          }).whereType<RemotePurchaseInvoice>().toList();
        }
      }
    } catch (_) {}

    return [];
  }

  /// جلب سجل المحادثة مع الفروع
  static Future<List<ChatMessage>> fetchChatMessages({String? branchId}) async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      String url = '${config.supabaseUrl}/rest/v1/owner_chat_messages?pharmacy_id=eq.${config.pharmacyId}';
      if (branchId != null) {
        url += '&branch_id=eq.$branchId';
      }
      url += '&order=created_at.asc&limit=100';

      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => ChatMessage.fromJson(j)).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  /// إرسال رسالة دردشة من المدير (نص، صوت، صورة)
  static Future<bool> sendChatMessage({
    required String text,
    String? audioBase64,
    String? imageBase64,
    String? branchId,
  }) async {
    final config = await getConfig();
    if (config == null) return false;

    try {
      final payload = {
        'id': 'msg-${DateTime.now().millisecondsSinceEpoch}',
        'pharmacy_id': config.pharmacyId,
        'branch_id': branchId ?? 'main',
        'device_id': 'mobile-owner',
        'sender_name': config.managerName,
        'sender_role': 'owner',
        'text': text,
        'audio_base64': audioBase64,
        'image_base64': imageBase64,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('${config.supabaseUrl}/rest/v1/owner_chat_messages'),
        headers: _headers(config.supabaseKey),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('sendChatMessage error: $e');
      return false;
    }
  }

  /// جلب فواتير المبيعات
  static Future<List<CloudSale>> fetchSales({int limit = 50}) async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      final url = '${config.supabaseUrl}/rest/v1/cloud_sales?pharmacy_id=eq.${config.pharmacyId}&order=created_at.desc&limit=$limit';
      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => CloudSale.fromJson(j)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// جلب إغلاقات الصناديق اليومية Z-Reports
  static Future<List<CloudDayClosing>> fetchDayClosings({int limit = 30}) async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      final url = '${config.supabaseUrl}/rest/v1/cloud_day_closings?pharmacy_id=eq.${config.pharmacyId}&order=created_at.desc&limit=$limit';
      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => CloudDayClosing.fromJson(j)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// جلب استشارات الروشتات الفورية
  static Future<List<OwnerTeleConsultation>> fetchTeleConsultations({String? status}) async {
    final config = await getConfig();
    if (config == null) return [];

    try {
      var url = '${config.supabaseUrl}/rest/v1/cloud_tele_consultations?pharmacy_id=eq.${config.pharmacyId}';
      if (status != null && status.isNotEmpty) {
        url += '&status=eq.$status';
      }
      url += '&order=created_at.desc&limit=50';

      final response = await http.get(Uri.parse(url), headers: _headers(config.supabaseKey)).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((j) => OwnerTeleConsultation.fromJson(j)).toList();
        }
      }
    } catch (_) {}
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

      final response = await http.patch(
        Uri.parse('${config.supabaseUrl}/rest/v1/cloud_tele_consultations?id=eq.$consultationId'),
        headers: _headers(config.supabaseKey),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
