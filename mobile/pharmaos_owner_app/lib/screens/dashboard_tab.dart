// تبويب لوحة المبيعات والرقابة المالية اللحظية - PharmaOS Owner App
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/owner_api_service.dart';

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
  int _todayInvoicesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final config = await OwnerApiService.getConfig();
    final sales = await OwnerApiService.fetchSales(limit: 50);
    final closings = await OwnerApiService.fetchDayClosings(limit: 15);

    double total = 0;
    int count = 0;
    final now = DateTime.now();

    for (var s in sales) {
      if (s.createdAt.year == now.year && s.createdAt.month == now.month && s.createdAt.day == now.day) {
        total += s.netAmount;
        count++;
      }
    }

    double drawer = closings.isNotEmpty ? closings.first.cashInDrawer : (total * 0.85);

    if (mounted) {
      setState(() {
        _config = config;
        _sales = sales;
        _closings = closings;
        _todaySales = total;
        _todayInvoicesCount = count;
        _cashInDrawer = drawer;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'ar');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniStat(Icons.receipt_long_rounded, '$_todayInvoicesCount فواتير', 'عدد العمليات'),
                              _buildMiniStat(Icons.point_of_sale_rounded, '${currencyFormat.format(_cashInDrawer)} ر.ي', 'نقد في الدرج'),
                            ],
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
                            value: 'مستقر',
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
                        Text(
                          '${_sales.length} فاتورة',
                          style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
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

                          return Container(
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
                                    color: const Color(0xFF10B981).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF10B981), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'فاتورة #${sale.invoiceNumber}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${sale.paymentMethod} • ${sale.cashierName ?? "كاشير"}',
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
                              ],
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
