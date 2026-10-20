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
    if (saved != null && saved.trim().startsWith('http')) return saved.trim();
    return defaultSupabaseUrl;
  }

  /// الحصول على مفتاح Supabase (لا يعود أبداً بقيمة null أو فارغة)
  static Future<String> getSupabaseAnonKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefCustomSupabaseKey);
    if (saved != null && saved.trim().length > 50 && !saved.contains('sb_publishable')) return saved.trim();
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
    final key = apiKey.trim().isNotEmpty ? apiKey.trim() : SupabaseConfig.anonKey;
    return {
      'apikey': key,
      'Authorization': 'Bearer $key',
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
        } else {
          debugPrint('[CloudSync] pharmacies register failed with status [${pRes.statusCode}]: ${pRes.body}');
        }
      } catch (e) {
        debugPrint('[CloudSync] pharmacies register exception: $e');
      }

      // 2.1 مزامنة فواتير المبيعات مع تفاصيل الأصناف (Cloud Sales & Items)
      final pharmacyIntId = int.tryParse(tenantConfig.pharmacyId) ?? 2;
      final branchIntId = int.tryParse(tenantConfig.branchId) ?? 2;

      final recentSales = await (db.select(db.sales)
            ..orderBy([(s) => drift.OrderingTerm.desc(s.createdAt)])
            ..limit(100))
          .get();

      if (recentSales.isNotEmpty) {
        final salesPayload = recentSales.map((s) {
          final net = s.totalAmount - s.discount;
          return {
            'pharmacy_id': pharmacyIntId,
            'branch_id': branchIntId,
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
                'Prefer': 'resolution=merge-duplicates,return=representation',
              },
              body: jsonEncode(salesPayload),
            )
            .timeout(SupabaseConfig.requestTimeout);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          syncedSalesCount = recentSales.length;
          debugPrint('[CloudSync] cloud_sales synced successfully ($syncedSalesCount records)');

          // مزامنة أصناف فواتير المبيعات
          try {
            final salesList = jsonDecode(res.body);
            if (salesList is List) {
              final List<Map<String, dynamic>> allSaleItems = [];
              for (final sRow in salesList) {
                final cloudSaleId = sRow['id'];
                final localSaleId = sRow['local_sale_id'];
                if (cloudSaleId != null && localSaleId is int) {
                  final items = await (db.select(db.saleItems)
                        ..where((i) => i.saleId.equals(localSaleId)))
                      .get();
                  for (final item in items) {
                    final med = await (db.select(db.medicines)
                          ..where((m) => m.id.equals(item.medicineId)))
                        .getSingleOrNull();
                    allSaleItems.add({
                      'pharmacy_id': pharmacyIntId,
                      'sale_id': cloudSaleId,
                      'medicine_name': med?.nameAr ?? 'دواء #${item.medicineId}',
                      'quantity': item.quantity,
                      'unit_price': item.unitPrice,
                      'total_price': item.total > 0
                          ? item.total
                          : (item.quantity * item.unitPrice),
                      'unit_name': item.unitName ?? 'باكت',
                    });
                  }
                }
              }
              if (allSaleItems.isNotEmpty) {
                await http.post(
                  Uri.parse('$supabaseUrl/rest/v1/cloud_sale_items'),
                  headers: {
                    ...headers,
                    'Prefer': 'resolution=merge-duplicates',
                  },
                  body: jsonEncode(allSaleItems),
                ).timeout(SupabaseConfig.requestTimeout);
                debugPrint('[CloudSync] synced ${allSaleItems.length} sale items');
              }
            }
          } catch (e) {
            debugPrint('[CloudSync] sale items sync error: $e');
          }
        } else {
          debugPrint('[CloudSync] cloud_sales failed with status [${res.statusCode}]: ${res.body}');
        }
      }

      // 2.2 مزامنة فواتير الشراء الشاملة (Purchases)
      try {
        final recentPurchases = await (db.select(db.purchases)
              ..orderBy([(p) => drift.OrderingTerm.desc(p.createdAt)])
              ..limit(50))
            .get();

        if (recentPurchases.isNotEmpty) {
          final purchasesAsSales = <Map<String, dynamic>>[];
          for (final p in recentPurchases) {
            final supplier = await (db.select(db.suppliers)
                  ..where((s) => s.id.equals(p.supplierId)))
                .getSingleOrNull();
            purchasesAsSales.add({
              'pharmacy_id': pharmacyIntId,
              'branch_id': branchIntId,
              'local_sale_id': 1000000 + p.id,
              'invoice_number': p.purchaseNumber,
              'total_amount': p.totalAmount,
              'discount_amount': 0.0,
              'net_amount': p.totalAmount,
              'paid_amount': p.paidAmount,
              'payment_method': p.paymentMethod,
              'cashier_name': 'مورد: ${supplier?.name ?? "عام"}',
              'customer_name': supplier?.name ?? 'مورد',
              'created_at': p.createdAt.toIso8601String(),
            });
          }

          final pRes = await http.post(
            Uri.parse('$supabaseUrl/rest/v1/cloud_sales'),
            headers: {
              ...headers,
              'Prefer': 'resolution=merge-duplicates,return=representation',
            },
            body: jsonEncode(purchasesAsSales),
          ).timeout(SupabaseConfig.requestTimeout);

          if (pRes.statusCode >= 200 && pRes.statusCode < 300) {
            final pList = jsonDecode(pRes.body);
            if (pList is List) {
              final List<Map<String, dynamic>> allPurItems = [];
              for (final pRow in pList) {
                final cloudSaleId = pRow['id'];
                final localPurId = (pRow['local_sale_id'] as int? ?? 0) - 1000000;
                if (cloudSaleId != null && localPurId > 0) {
                  final pItems = await (db.select(db.purchaseItems)
                        ..where((i) => i.purchaseId.equals(localPurId)))
                      .get();
                  for (final pi in pItems) {
                    final med = await (db.select(db.medicines)
                          ..where((m) => m.id.equals(pi.medicineId)))
                        .getSingleOrNull();
                    allPurItems.add({
                      'pharmacy_id': pharmacyIntId,
                      'sale_id': cloudSaleId,
                      'medicine_name': med?.nameAr ?? 'صنف #${pi.medicineId}',
                      'quantity': pi.quantity,
                      'unit_price': pi.unitCost,
                      'total_price': pi.subtotal > 0
                          ? pi.subtotal
                          : (pi.quantity * pi.unitCost),
                      'unit_name': pi.unitName ?? 'عبوة',
                    });
                  }
                }
              }
              if (allPurItems.isNotEmpty) {
                await http.post(
                  Uri.parse('$supabaseUrl/rest/v1/cloud_sale_items'),
                  headers: {
                    ...headers,
                    'Prefer': 'resolution=merge-duplicates',
                  },
                  body: jsonEncode(allPurItems),
                ).timeout(SupabaseConfig.requestTimeout);
                debugPrint('[CloudSync] synced ${allPurItems.length} purchase items');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[CloudSync] purchases sync error: $e');
      }

      // 2.3 مزامنة فواتير المرتجعات (Returns)
      try {
        final recentReturns = await (db.select(db.returns)
              ..orderBy([(r) => drift.OrderingTerm.desc(r.createdAt)])
              ..limit(50))
            .get();

        if (recentReturns.isNotEmpty) {
          final returnsAsSales = <Map<String, dynamic>>[];
          for (final r in recentReturns) {
            returnsAsSales.add({
              'pharmacy_id': pharmacyIntId,
              'branch_id': branchIntId,
              'local_sale_id': 2000000 + r.id,
              'invoice_number': 'RET-${r.id.toString().padLeft(4, '0')}',
              'total_amount': r.totalAmount,
              'discount_amount': 0.0,
              'net_amount': r.totalAmount,
              'paid_amount': r.totalAmount,
              'payment_method': r.paymentMethod,
              'cashier_name': 'مرتجع: ${r.reason ?? "استرجاع أصناف"}',
              'customer_name': 'مرتجع مبيعات',
              'created_at': r.createdAt.toIso8601String(),
            });
          }

          final rRes = await http.post(
            Uri.parse('$supabaseUrl/rest/v1/cloud_sales'),
            headers: {
              ...headers,
              'Prefer': 'resolution=merge-duplicates,return=representation',
            },
            body: jsonEncode(returnsAsSales),
          ).timeout(SupabaseConfig.requestTimeout);

          if (rRes.statusCode >= 200 && rRes.statusCode < 300) {
            final rList = jsonDecode(rRes.body);
            if (rList is List) {
              final List<Map<String, dynamic>> allRetItems = [];
              for (final rRow in rList) {
                final cloudSaleId = rRow['id'];
                final localRetId = (rRow['local_sale_id'] as int? ?? 0) - 2000000;
                if (cloudSaleId != null && localRetId > 0) {
                  final retItems = await (db.select(db.returnItems)
                        ..where((i) => i.returnId.equals(localRetId)))
                      .get();
                  for (final ri in retItems) {
                    final med = await (db.select(db.medicines)
                          ..where((m) => m.id.equals(ri.medicineId)))
                        .getSingleOrNull();
                    allRetItems.add({
                      'pharmacy_id': pharmacyIntId,
                      'sale_id': cloudSaleId,
                      'medicine_name': med?.nameAr ?? 'صنف مرتجع #${ri.medicineId}',
                      'quantity': ri.quantity,
                      'unit_price': ri.unitPrice,
                      'total_price': ri.subtotal > 0
                          ? ri.subtotal
                          : (ri.quantity * ri.unitPrice),
                      'unit_name': 'وحدة',
                    });
                  }
                }
              }
              if (allRetItems.isNotEmpty) {
                await http.post(
                  Uri.parse('$supabaseUrl/rest/v1/cloud_sale_items'),
                  headers: {
                    ...headers,
                    'Prefer': 'resolution=merge-duplicates',
                  },
                  body: jsonEncode(allRetItems),
                ).timeout(SupabaseConfig.requestTimeout);
                debugPrint('[CloudSync] synced ${allRetItems.length} return items');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[CloudSync] returns sync error: $e');
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
          debugPrint('[CloudSync] cloud_day_closings synced successfully ($syncedClosingsCount records)');
        } else {
          debugPrint('[CloudSync] cloud_day_closings failed with status [${res.statusCode}]: ${res.body}');
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
          debugPrint('[CloudSync] cloud_medicines synced successfully ($syncedMedsCount records)');
        } else {
          debugPrint('[CloudSync] cloud_medicines failed with status [${res.statusCode}]: ${res.body}');
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
