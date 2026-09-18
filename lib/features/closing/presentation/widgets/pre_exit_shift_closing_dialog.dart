// واجهة إغلاق اليومية الشاملة وحساب الصندوق والمسحوبات قبل الخروج - PharmaOS
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/shift_manager_service.dart';
import '../../../../core/services/official_date_time_service.dart';
import '../../domain/services/daily_closing_service.dart';

class PreExitShiftClosingDialog extends StatefulWidget {
  final VoidCallback onProceedToBackupAndExit;

  const PreExitShiftClosingDialog({
    super.key,
    required this.onProceedToBackupAndExit,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onProceedToBackupAndExit}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PreExitShiftClosingDialog(onProceedToBackupAndExit: onProceedToBackupAndExit),
    );
  }

  @override
  State<PreExitShiftClosingDialog> createState() => _PreExitShiftClosingDialogState();
}

class _PreExitShiftClosingDialogState extends State<PreExitShiftClosingDialog> {
  final _countedCashController = TextEditingController();
  final _varianceReasonController = TextEditingController();

  LiveShiftStats? _stats;
  ActiveShiftModel? _activeShift;
  bool _isLoading = true;
  bool _isClosing = false;
  bool _createExpenseForMissing = true;

  double _actualCountedCash = 0.0;
  DateTime _currentTime = DateTime.now();
  StreamSubscription? _clockSubscription;

  @override
  void initState() {
    super.initState();
    _clockSubscription = OfficialDateTimeService.secondStream.listen((dt) {
      if (mounted) setState(() => _currentTime = dt);
    });
    _loadShiftData();
  }

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);
    final active = await ShiftManagerService.getActiveShift();
    final stats = await ShiftManagerService.calculateLiveShiftStats();

    if (mounted) {
      setState(() {
        _activeShift = active;
        _stats = stats;
        _actualCountedCash = stats.expectedCashInDrawer;
        _countedCashController.text = stats.expectedCashInDrawer.toStringAsFixed(0);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _clockSubscription?.cancel();
    _countedCashController.dispose();
    _varianceReasonController.dispose();
    super.dispose();
  }

  double get _variance => _actualCountedCash - (_stats?.expectedCashInDrawer ?? 0.0);

  Future<void> _confirmAndClose() async {
    if (_stats == null) return;
    setState(() => _isClosing = true);

    try {
      await ShiftManagerService.closeActiveShift(
        countedClosingCash: _actualCountedCash,
        expectedClosingCash: _stats!.expectedCashInDrawer,
        varianceReason: _varianceReasonController.text.trim().isNotEmpty ? _varianceReasonController.text.trim() : 'مسحوبات وتسويات نقدية',
        createExpenseVoucherForDeficit: _variance < -0.5 && _createExpenseForMissing,
      );

      if (mounted) {
        Navigator.pop(context);
        // المتابعة المباشرة لنافذة النسخ السحابي الثلاثي والإغلاق
        widget.onProceedToBackupAndExit();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClosing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الإغلاق: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printThermalZReport() async {
    if (_stats == null) return;
    try {
      final summary = await DailyClosingService.calculateShiftSummary(
        shiftStart: _stats!.shiftStart,
        actualCashCount: _actualCountedCash,
        cashierName: _activeShift?.cashierName ?? 'الكاشير المناوب',
        openingCash: _stats!.openingCash,
      );
      await DailyClosingService.printShiftZReport(summary);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال تقرير Z-Report إلى الطابعة الحرارية 🖨️'), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الطباعة: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 840,
          constraints: const BoxConstraints(maxHeight: 780),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF34D399), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'إغلاق اليومية ومطابقة الصندوق والمسحوبات',
                                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              if (_activeShift != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('وردية #${_activeShift!.shiftNumber}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            OfficialDateTimeService.formatDateArabicWithDay(_currentTime),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Live Clock
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled, color: Color(0xFF34D399), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            OfficialDateTimeService.formatLiveTime(_currentTime),
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. بطاقات الإحصاءات الأساسية للوردية
                            Row(
                              children: [
                                _buildStatCard('عدد المبيعات', '${_stats!.salesCount} فاتورة', Icons.shopping_bag_outlined, const Color(0xFF38BDF8)),
                                const SizedBox(width: 12),
                                _buildStatCard('إجمالي المبيعات', '${_stats!.totalSalesAmount.toStringAsFixed(0)} ر.ي', Icons.monetization_on_outlined, const Color(0xFF34D399)),
                                const SizedBox(width: 12),
                                _buildStatCard('المصروفات والسحبيات', '${(_stats!.totalExpensesAmount + _stats!.totalVendorPaymentsAmount).toStringAsFixed(0)} ر.ي', Icons.payments_outlined, const Color(0xFFF87171)),
                                const SizedBox(width: 12),
                                _buildStatCard('المرتجعات النقدية', '${_stats!.totalReturnsAmount.toStringAsFixed(0)} ر.ي', Icons.keyboard_return_rounded, const Color(0xFFFBBF24)),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // 2. أكثر الأدوية مبيعاً في هذه اليومية
                            if (_stats!.topSellingItems.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.auto_graph_rounded, color: Color(0xFF38BDF8), size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'أكثر الأصناف مبيعاً في هذه الوردية (Top Sellers):',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: _stats!.topSellingItems.map((item) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.white10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(item.medicineName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text('${item.quantitySold} قطعة', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                                              ),
                                              const SizedBox(width: 6),
                                              Text('(${item.totalRevenue.toStringAsFixed(0)} ر.ي)', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],

                            // 3. مطابقة الدرج والصندوق الختامي
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.point_of_sale_rounded, color: Color(0xFF34D399), size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'مطابقة النقد النهائي في الدرج (Cash Reconciliation)',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      // النقد المحسوب تلقائياً
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('النقد المحسوب بالنظام (المتوقع بالدرج)', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_stats!.expectedCashInDrawer.toStringAsFixed(0)} ر.ي',
                                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // النقد الفعلي المعدود
                                      Expanded(
                                        child: TextField(
                                          controller: _countedCashController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            labelText: 'النقد الفعلي الموجود بالدرج الآن',
                                            labelStyle: const TextStyle(color: Color(0xFF34D399), fontSize: 13),
                                            suffixText: 'ر.ي',
                                            suffixStyle: const TextStyle(color: Colors.white70),
                                            filled: true,
                                            fillColor: const Color(0xFF0F172A),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFF34D399)),
                                            ),
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              _actualCountedCash = double.tryParse(val) ?? _stats!.expectedCashInDrawer;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // بطاقة الفارق (عجز / زيادة / مطابق)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _variance.abs() < 1.0
                                          ? const Color(0xFF059669).withValues(alpha: 0.15)
                                          : (_variance < 0 ? const Color(0xFFDC2626).withValues(alpha: 0.15) : const Color(0xFFD97706).withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _variance.abs() < 1.0
                                            ? const Color(0xFF059669)
                                            : (_variance < 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _variance.abs() < 1.0
                                              ? Icons.check_circle_rounded
                                              : (_variance < 0 ? Icons.warning_rounded : Icons.info_rounded),
                                          color: _variance.abs() < 1.0
                                              ? const Color(0xFF10B981)
                                              : (_variance < 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _variance.abs() < 1.0
                                                ? 'رصيد الدرج مطابق تماماً لسجلات النظام المحاسبية (فارق: 0 ر.ي) ✅'
                                                : (_variance < 0
                                                    ? 'تنبيه: يوجد عجز في الصندوق قدره (${_variance.abs().toStringAsFixed(0)} ر.ي)'
                                                    : 'تنبيه: توجد زيادة نقدية في الصندوق قدرها (+${_variance.toStringAsFixed(0)} ر.ي)'),
                                            style: TextStyle(
                                              color: _variance.abs() < 1.0
                                                  ? const Color(0xFF10B981)
                                                  : (_variance < 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // في حال وجود عجز: خيار توثيق المسحوبات المنسية
                                  if (_variance < -0.5) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: _createExpenseForMissing,
                                                activeColor: Colors.redAccent,
                                                onChanged: (val) => setState(() => _createExpenseForMissing = val ?? true),
                                              ),
                                              const Expanded(
                                                child: Text(
                                                  'تسجيل سند صرف مصروف تلقائي بالمبلغ المفقود/المسحوب لتصفير العجز المحاسبي',
                                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_createExpenseForMissing) ...[
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: _varianceReasonController,
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                              decoration: InputDecoration(
                                                labelText: 'سبب ومبرر المسحوبات (مثال: مسحوبات صاحب الصيدلية، مصاريف نثريات لم تقيد)',
                                                labelStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                                filled: true,
                                                fillColor: const Color(0xFF1E293B),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('إلغاء والعودة للنظام'),
                      onPressed: _isClosing ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF38BDF8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('طباعة تقرير Z-Report حراري 🖨️'),
                      onPressed: _isClosing ? null : _printThermalZReport,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isClosing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('تأكيد الإغلاق وتأمين النسخ والخروج 🔒', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      onPressed: _isClosing ? null : _confirmAndClose,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
