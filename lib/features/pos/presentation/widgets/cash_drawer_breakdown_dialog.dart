import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/official_date_time_service.dart';
import '../../../../core/services/shift_manager_service.dart';
import '../../../cash_register/domain/repositories/cash_register_repository.dart';

class CashDrawerBreakdownDialog extends StatefulWidget {
  final VoidCallback? onRefresh;

  const CashDrawerBreakdownDialog({super.key, this.onRefresh});

  static Future<void> show(BuildContext context, {VoidCallback? onRefresh}) {
    return showDialog(
      context: context,
      builder: (context) => CashDrawerBreakdownDialog(onRefresh: onRefresh),
    );
  }

  @override
  State<CashDrawerBreakdownDialog> createState() => _CashDrawerBreakdownDialogState();
}

class _CashDrawerBreakdownDialogState extends State<CashDrawerBreakdownDialog> {
  bool _isLoading = true;
  LiveShiftStats? _stats;
  ActiveShiftModel? _shift;
  List<dynamic> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final shift = await ShiftManagerService.getActiveShift();
      final stats = await ShiftManagerService.getLiveStats();
      final txs = await sl<CashRegisterRepository>().getTransactions(walletId: null);

      if (mounted) {
        setState(() {
          _shift = shift;
          _stats = stats;
          _recentTransactions = txs.take(15).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.point_of_sale, color: Color(0xFF0284C7), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'تفصيل رصيد درج الصيدلية (الكاشير)',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shift != null
                                      ? 'الوردية #${_shift!.id} | الكاشير: ${_shift!.cashierName} | البدء: ${OfficialDateTimeService.formatDateArabicWithDay(_shift!.startTime)}'
                                      : 'لا توجد وردية نشطة حالياً',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                            tooltip: 'تحديث الحسابات',
                            onPressed: _loadData,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),

                      // Formula Cards Grid
                      if (_stats != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'العهدة الافتتاحية',
                                amount: _stats!.openingCash,
                                icon: Icons.lock_open,
                                color: const Color(0xFF6366F1),
                                badgeText: 'رصيد البداية',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'المبيعات النقدية (+)',
                                amount: _stats!.totalCashSales,
                                icon: Icons.arrow_downward,
                                color: const Color(0xFF10B981),
                                badgeText: '+ وارد للدرج',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: 'المرتجعات النقدية (-)',
                                amount: _stats!.totalReturnsAmount,
                                icon: Icons.keyboard_return,
                                color: const Color(0xFFF59E0B),
                                badgeText: '- منصرف نقدي',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'المصروفات ودفعات الموردين (-)',
                                amount: _stats!.totalExpensesAmount + _stats!.totalVendorPaymentsAmount,
                                icon: Icons.arrow_upward,
                                color: const Color(0xFFEF4444),
                                badgeText: '- منصرف نقدي',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Total Net In Drawer Big Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.account_balance_wallet, color: Color(0xFF34D399), size: 28),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'صافي النقد المتوقع بالدرج الآن (=)',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '(العهدة الافتتاحية + المبيعات النقدية - المرتجعات - المصروفات)',
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${_stats!.expectedCashInDrawer.toStringAsFixed(0)} ر.ي',
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      const Text(
                        'آخر الحركات النقدية بالدرج:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),

                      // Transactions List
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: _recentTransactions.isEmpty
                              ? const Center(
                                  child: Text('لا توجد حركات مسجلة بالدرج حتى الآن', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  itemCount: _recentTransactions.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  itemBuilder: (context, index) {
                                    final tx = _recentTransactions[index];
                                    final isIncome = tx.type == 'IN';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                            size: 16,
                                            color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              tx.description,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            '${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} ر.ي',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          ),
                          child: const Text('إغلاق'),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(badgeText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(0)} ر.ي',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}
