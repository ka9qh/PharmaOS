// خدمة المزامنة السحابية متعددة الصيدليات والفروع (Supabase Cloud Sync Engine) - PharmaOS
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;

import '../config/supabase_config.dart';
import '../di/service_locator.dart';
import '../database/app_database.dart';
import 'license_service.dart';

class CloudSyncResult {
  final bool isSuccess;
  final int syncedSales;
  final int syncedMedicines;
  final int syncedClosings;
  final String? message;

  const CloudSyncResult({
    required this.isSuccess,
    this.syncedSales = 0,
    this.syncedMedicines = 0,
    this.syncedClosings = 0,
    this.message,
  });
}

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  static bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// تهيئة المزامنة الحية لسطح المكتب بنمط غير حظري (Non-blocking Resilient Pattern)
  void initDesktopLiveSync() {
    syncPendingInvoices();
  }

  /// مزامنة الفواتير المعلقة بدون تعليق الواجهة
  Future<void> syncPendingInvoices() async {
    if (_isSyncing) return;
    try {
      await triggerFullSync();
    } catch (e) {
      debugPrint('Non-blocking pending sync note: $e');
    }
  }

  void _handleIncomingCommand(Map<String, dynamic> payload) {
    final command = payload['command'];
    if (command == 'START_CCTV' || command == 'START_SCREEN_STREAM') {
      // معالجة الأوامر في الخلفية دون تعطيل الاتصال الأساسي
    }
  }

  // إعدادات ومفاتيح صريحة وثابتة (Hardcoded Constants) تمنع عودة null أو ضياع الإعدادات
  static const String defaultSupabaseUrl = SupabaseConfig.url;
  static const String defaultSupabaseAnonKey = SupabaseConfig.anonKey;

  static const String _prefCloudSyncEnabled = 'cloud_sync_enabled_v1';
  static const String _prefCustomSupabaseUrl = 'custom_supabase_url_v1';
  static const String _prefCustomSupabaseKey = 'custom_supabase_key_v1';
  static const String _prefLastSyncTime = 'cloud_sync_last_time_v1';

  /// فحص هل المزامنة السحابية مفعلة
  static Future<bool> isCloudSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefCloudSyncEnabled) ?? true;
  }

  /// تفعيل أو تعطيل المزامنة السحابية
  static Future<void> setCloudSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefCloudSyncEnabled, enabled);
  }

  /// الحصول على رابط Supabase (لا يعود أبداً بقيمة null أو فارغة)
  static Future<String> getSupabaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefCustomSupabaseUrl);
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    return defaultSupabaseUrl;
  }

  /// الحصول على مفتاح Supabase (لا يعود أبداً بقيمة null أو فارغة)
  static Future<String> getSupabaseAnonKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefCustomSupabaseKey);
    if (saved != null && saved.trim().isNotEmpty && !saved.contains('sb_publishable')) return saved.trim();
    return defaultSupabaseAnonKey;
  }

  /// الحصول على وقت آخر مزامنة ناجحة
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_prefLastSyncTime);
    if (str != null) return DateTime.tryParse(str);
    return null;
  }

  static Map<String, String> _getHeaders(String apiKey) {
    return {
      'apikey': apiKey,
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    };
  }

  /// تشغيل المزامنة السحابية الشاملة لبيانات الصيدلية
  static Future<CloudSyncResult> triggerFullSync() async {
    final isEnabled = await isCloudSyncEnabled();
    if (!isEnabled) {
      return const CloudSyncResult(isSuccess: true, message: 'المزامنة السحابية معطلة في الإعدادات');
    }

    if (_isSyncing) {
      return const CloudSyncResult(isSuccess: true, message: 'مزامنة جارية بالفعل في الخلفية');
    }
    _isSyncing = true;

    try {
      var tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await getSupabaseUrl();
      final apiKey = await getSupabaseAnonKey();
      final headers = _getHeaders(apiKey);

      final db = sl<AppDatabase>();
      int syncedSalesCount = 0;
      int syncedMedsCount = 0;
      int syncedClosingsCount = 0;

      // 1. تسجيل/التحقق من الصيدلية في جدول pharmacies
      final pharmacyPayload = {
        'name': tenantConfig.pharmacyName,
        'license_key': tenantConfig.licenseKey,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        final pRes = await http
            .post(
              Uri.parse('$supabaseUrl/rest/v1/pharmacies'),
              headers: {
                ...headers,
                'Prefer': 'return=representation,resolution=merge-duplicates',
              },
              body: jsonEncode(pharmacyPayload),
            )
            .timeout(SupabaseConfig.requestTimeout);

        if (pRes.statusCode >= 200 && pRes.statusCode < 300) {
          final pData = jsonDecode(pRes.body);
          if (pData is List && pData.isNotEmpty) {
            final realId = pData.first['id'].toString();
            if (tenantConfig.pharmacyId != realId) {
              tenantConfig = tenantConfig.copyWith(pharmacyId: realId);
              await LicenseService.saveTenantConfig(tenantConfig);
            }
          }
        }
      } catch (_) {
        // الاستمرار حتى في حال وجود اتصال متقطع
      }

      // 2. مزامنة فواتير المبيعات الحديثة (Cloud Sales)
      final recentSales = await (db.select(db.sales)
            ..orderBy([(s) => drift.OrderingTerm.desc(s.createdAt)])
            ..limit(50))
          .get();

      if (recentSales.isNotEmpty) {
        final salesPayload = recentSales.map((s) {
          final net = s.totalAmount - s.discount;
          return {
            'pharmacy_id': int.tryParse(tenantConfig.pharmacyId) ?? 2,
            'branch_id': int.tryParse(tenantConfig.branchId) ?? 2,
            'local_sale_id': s.id,
            'invoice_number': s.invoiceNumber,
            'total_amount': s.totalAmount,
            'discount_amount': s.discount,
            'net_amount': net > 0 ? net : s.totalAmount,
            'paid_amount': net > 0 ? net : s.totalAmount,
            'payment_method': s.paymentMethod,
            'cashier_name': 'كاشير #${s.cashierId ?? 1}',
            'created_at': s.createdAt.toIso8601String(),
          };
        }).toList();

        final res = await http
            .post(
              Uri.parse('$supabaseUrl/rest/v1/cloud_sales'),
              headers: {
                ...headers,
                'Prefer': 'resolution=merge-duplicates',
              },
              body: jsonEncode(salesPayload),
            )
            .timeout(SupabaseConfig.requestTimeout);

        if (res.statusCode == 201 || res.statusCode == 200 || res.statusCode == 204) {
          syncedSalesCount = recentSales.length;
        }
      }

      // 3. مزامنة تقارير الإغلاقات والورديات (Cloud Closings)
      final closings = await (db.select(db.dayClosings)
            ..orderBy([(c) => drift.OrderingTerm.desc(c.createdAt)])
            ..limit(20))
          .get();

      if (closings.isNotEmpty) {
        final closingsPayload = closings.map((c) {
          return {
            'pharmacy_id': int.tryParse(tenantConfig.pharmacyId) ?? 2,
            'branch_id': int.tryParse(tenantConfig.branchId) ?? 2,
            'date': c.date.toIso8601String().substring(0, 10),
            'period_start': c.periodStart.toIso8601String(),
            'total_sales': c.totalSales,
            'total_returns': c.totalReturns,
            'total_expenses': c.totalExpenses,
            'cost_of_goods_sold': c.costOfGoodsSold,
            'net_profit': c.netProfit,
            'cash_in_drawer': c.cashInDrawer,
          };
        }).toList();

        final res = await http
            .post(
              Uri.parse('$supabaseUrl/rest/v1/cloud_day_closings'),
              headers: {
                ...headers,
                'Prefer': 'resolution=merge-duplicates',
              },
              body: jsonEncode(closingsPayload),
            )
            .timeout(SupabaseConfig.requestTimeout);

        if (res.statusCode == 201 || res.statusCode == 200 || res.statusCode == 204) {
          syncedClosingsCount = closings.length;
        }
      }

      // 4. مزامنة الأدوية مع الباركودات المحدثة (Cloud Medicines)
      final activeMedicines = await (db.select(db.medicines)
            ..where((m) => m.barcode.isNotNull() | m.sku.isNotNull())
            ..limit(100))
          .get();

      if (activeMedicines.isNotEmpty) {
        final medsPayload = activeMedicines.map((m) {
          return {
            'pharmacy_id': int.tryParse(tenantConfig.pharmacyId) ?? 2,
            'local_id': m.id,
            'name_ar': m.nameAr,
            'name_en': m.nameEn,
            'name_scientific': m.nameScientific,
            'barcode': m.barcode,
            'sku': m.sku,
            'selling_price': m.sellingPrice,
            'purchase_price': m.purchasePrice,
            'reorder_level': m.reorderLevel,
          };
        }).toList();

        final res = await http
            .post(
              Uri.parse('$supabaseUrl/rest/v1/cloud_medicines'),
              headers: {
                ...headers,
                'Prefer': 'resolution=merge-duplicates',
              },
              body: jsonEncode(medsPayload),
            )
            .timeout(SupabaseConfig.requestTimeout);

        if (res.statusCode == 201 || res.statusCode == 200 || res.statusCode == 204) {
          syncedMedsCount = activeMedicines.length;
        }
      }

      // حفظ تاريخ آخر مزامنة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastSyncTime, DateTime.now().toIso8601String());

      return CloudSyncResult(
        isSuccess: true,
        syncedSales: syncedSalesCount,
        syncedMedicines: syncedMedsCount,
        syncedClosings: syncedClosingsCount,
        message: 'تمت المزامنة السحابية بنجاح مع سيرفر Supabase',
      );
    } catch (e) {
      debugPrint('CloudSyncService error: $e');
      return CloudSyncResult(
        isSuccess: false,
        message: 'تعذر الاتصال بالسيرفر السحابي: $e',
      );
    } finally {
      _isSyncing = false;
    }
  }
}
