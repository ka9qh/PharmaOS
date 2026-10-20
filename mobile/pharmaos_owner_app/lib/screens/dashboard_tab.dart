// تبويب لوحة المبيعات والرقابة المالية اللحظية - PharmaOS Owner App
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/owner_api_service.dart';
import '../services/app_updater_service.dart';
import '../widgets/luxury_app_avatar.dart';
import 'comprehensive_invoices_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _isLoading = false;
  OwnerTenantConfig? _config;
  List<CloudSale> _sales = [];
  List<CloudDayClosing> _closings = [];
  double _todaySales = 0;
  double _cashInDrawer = 0;
  double _walletsSales = 0;
  double _creditSales = 0;
  int _todayInvoicesCount = 0;
  OwnerAppUpdateInfo? _availableUpdate;
  Timer? _refreshTimer;

  static const String _prefCachedSales = 'cached_dashboard_sales_v1';
  static const String _prefCachedClosings = 'cached_dashboard_closings_v1';

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadData(silent: true);
    _checkUpdates();
    // تحديث تلقائي كل 10 ثوانٍ (Reactivity)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadData(silent: true);
    });
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final config = await OwnerApiService.getConfig();
      final salesJson = prefs.getString(_prefCachedSales);
      final closingsJson = prefs.getString(_prefCachedClosings);

      List<CloudSale> cachedSales = [];
      List<CloudDayClosing> cachedClosings = [];

      if (salesJson != null) {
        final list = jsonDecode(salesJson) as List;
        cachedSales = list.map((j) => CloudSale.fromJson(j)).toList();
      }
      if (closingsJson != null) {
        final list = jsonDecode(closingsJson) as List;
        cachedClosings = list.map((j) => CloudDayClosing.fromJson(j)).toList();
      }

      if (mounted && (cachedSales.isNotEmpty || cachedClosings.isNotEmpty)) {
        _applyData(cachedSales, cachedClosings, config: config);
      }
    } catch (_) {}
  }

  void _applyData(List<CloudSale> sales, List<CloudDayClosing> closings,
      {OwnerTenantConfig? config}) {
    double total = 0;
    double cashTotal = 0;
    double walletsTotal = 0;
    double creditTotal = 0;
    int count = 0;
    final now = DateTime.now();

    for (var s in sales) {
      if (s.createdAt.year == now.year &&
          s.createdAt.month == now.month &&
          s.createdAt.day == now.day) {
        total += s.netAmount;
        final method = s.paymentMethod.toLowerCase();
        if (method.contains('نقد') || method == 'cash') {
          cashTotal += s.netAmount;
        } else if (method.contains('آجل') ||
            method.contains('اجل') ||
            method == 'debt' ||
            method == 'credit') {
          creditTotal += s.netAmount;
        } else {
          walletsTotal += s.netAmount;
        }
        count++;
      }
    }

    double drawer =
        closings.isNotEmpty ? closings.first.cashInDrawer : cashTotal;

    if (mounted) {
      setState(() {
        if (config != null) _config = config;
        _sales = sales;
        _closings = closings;
        _todaySales = total;
        _todayInvoicesCount = count;
        _cashInDrawer = drawer;
        _walletsSales = walletsTotal;
        _creditSales = creditTotal;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUpdates() async {
    final update = await AppUpdaterService.checkForUpdates();
    if (mounted && update != null) {
      setState(() => _availableUpdate = update);
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && _sales.isEmpty) setState(() => _isLoading = true);
    try {
      // جلب متوازي فوري لا يحجب الشاشة
      final results = await Future.wait([
        OwnerApiService.getConfig(),
        OwnerApiService.fetchSales(limit: 50),
        OwnerApiService.fetchDayClosings(limit: 15),
      ]);

      final config = results[0] as OwnerTenantConfig?;
      final sales = results[1] as List<CloudSale>;
      final closings = results[2] as List<CloudDayClosing>;

      _applyData(sales, closings, config: config);

      // حفظ الكاش محلياً في الخلفية لفتحه فورياً عند انقطاع أو ضعف النت
      SharedPreferences.getInstance().then((prefs) {
        try {
          prefs.setString(_prefCachedSales,
              jsonEncode(sales.map((s) => s.toJson()).toList()));
          prefs.setString(_prefCachedClosings,
              jsonEncode(closings.map((c) => c.toJson()).toList()));
        } catch (_) {}
      });
    } catch (e) {
      if (mounted && _sales.isEmpty) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'ar');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1322).withValues(alpha: 0.85),
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: LuxuryAppAvatar(size: 38, showBadge: true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _config?.pharmacyName ?? 'لوحة إدارة الصيدلية',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'مرحباً ${_config?.managerName ?? "المدير"} • كود #${_config?.pharmacyId ?? 1}',
              style: const TextStyle(fontSize: 11, color: Colors.cyanAccent),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.system_update_alt_rounded, color: Colors.white),
                tooltip: 'فحص التحديثات وتنزيل الإصدار الجديد',
                onPressed: () async {
                  final update = await AppUpdaterService.checkForUpdates();
                  if (!mounted) return;
                  if (update != null) {
                    setState(() => _availableUpdate = update);
                    AppUpdaterService.showUpdateDialog(context, update);
                  } else {
                    AppUpdaterService.showNoUpdateDialog(context);
                  }
                },
              ),
              if (_availableUpdate != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('!', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'تحديث البيانات اللحظية',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.cyanAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // إشعار التحديث العائم في حال توفر إصدار جديد
                    if (_availableUpdate != null) ...[
                      InkWell(
                        onTap: () => AppUpdaterService.showUpdateDialog(context, _availableUpdate!),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF065F46), Color(0xFF047857)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF34D399), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'تحديث جديد متاح لتطبيق المدير (v${_availableUpdate!.version}) 🚀',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'اضغط هنا لعرض تفاصيل التحديث والتثبيت الفوري',
                                      style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'تحديث الآن 📥',
                                  style: TextStyle(
                                    color: Color(0xFF065F46),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // بطاقة الإيرادات الرئيسية
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('مبيعات اليوم الإجمالية', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.fiber_manual_record, color: Colors.greenAccent, size: 10),
                                    SizedBox(width: 4),
                                    Text('مباشر سحابي', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                currencyFormat.format(_todaySales),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('ريال يمني', style: TextStyle(fontSize: 14, color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMiniStat(Icons.receipt_long_rounded, '$_todayInvoicesCount', 'العمليات'),
                                Container(width: 1, height: 26, color: Colors.white12),
                                _buildMiniStat(Icons.point_of_sale_rounded, '${currencyFormat.format(_cashInDrawer)}', 'نقد الدرج'),
                                Container(width: 1, height: 26, color: Colors.white12),
                                _buildMiniStat(Icons.account_balance_wallet_rounded, '${currencyFormat.format(_walletsSales)}', 'المحافظ'),
                                Container(width: 1, height: 26, color: Colors.white12),
                                _buildMiniStat(Icons.credit_score_rounded, '${currencyFormat.format(_creditSales)}', 'الآجل'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // شبكة الإحصائيات السريعة
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'الديون والمؤجل',
                            value: '${currencyFormat.format(_creditSales)} ر.ي',
                            subtitle: 'سجل العملاء متزامن',
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'إقفال الوردية',
                            value: _closings.isNotEmpty ? 'مطابق' : 'جاري العمل',
                            subtitle: 'تقرير Z سحابي',
                            icon: Icons.verified_rounded,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // شريط آخر الفواتير المنفذة في الصيدلية
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'آخر فواتير المبيعات اللحظية',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ComprehensiveInvoicesScreen()),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  'عرض الكل (${_sales.length})',
                                  style: const TextStyle(fontSize: 12, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.cyanAccent, size: 11),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_sales.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text('لا توجد مبيعات متزامنة بعد', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _sales.take(15).length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final sale = _sales[index];
                          final timeStr = DateFormat('hh:mm a').format(sale.createdAt);

                          final isCash = sale.paymentMethod.contains('نقد') || sale.paymentMethod.toLowerCase() == 'cash';
                          final isCredit = sale.paymentMethod.contains('آجل') || sale.paymentMethod.contains('اجل') || sale.paymentMethod.toLowerCase() == 'debt';
                          final badgeColor = isCash ? const Color(0xFF10B981) : (isCredit ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6));
                          final badgeIcon = isCash ? Icons.payments_rounded : (isCredit ? Icons.receipt_long_rounded : Icons.account_balance_wallet_rounded);

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => InvoiceDetailsSheet.show(context, sale),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(badgeIcon, color: badgeColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'فاتورة #${sale.invoiceNumber}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                sale.paymentMethod,
                                                style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'كاشير: ${sale.cashierName ?? "المناوب"}${sale.customerName != null && sale.customerName!.isNotEmpty ? " • عميل: ${sale.customerName}" : ""}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${currencyFormat.format(sale.netAmount)} ر.ي',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                    ],
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_left_rounded, color: Colors.white24, size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
        ],
      ),
    );
  }
}
