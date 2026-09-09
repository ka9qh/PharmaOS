// شاشة إغلاق اليومية، تقفيل الورديات، والأرباح والخسائر المتقدمة - PharmaOS
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:drift/drift.dart' as drift;

import '../../domain/services/daily_closing_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';

class DailyClosingScreen extends StatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  State<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends State<DailyClosingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: تقفيل الوردية الحالية
  DateTime _shiftStartTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8, 0);
  final TextEditingController _cashierNameController = TextEditingController(text: 'الكاشير الرئيسي');
  final TextEditingController _openingCashController = TextEditingController(text: '0');
  final TextEditingController _actualCashController = TextEditingController(text: '0');
  ShiftHandoverSummary? _shiftSummary;
  bool _isLoadingShift = false;
  bool _isSavingShift = false;

  // Tab 2: الأرباح والخسائر المتقدمة
  String _selectedPeriodFilter = 'today'; // today, yesterday, week, month, custom
  DateTime _plStartDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _plEndDate = DateTime.now();
  FinancialPeriodSummary? _plSummary;
  bool _isLoadingPL = false;

  // Tab 3: سجل الإغلاقات
  DailyClosingSummary? _todayClosingSummary;
  List<DayClosingRow> _previousClosings = [];
  bool _isLoadingHistory = false;
  bool _isPerformingClosing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllTabs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cashierNameController.dispose();
    _openingCashController.dispose();
    _actualCashController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTabs() async {
    await Future.wait([
      _calculateShiftData(),
      _loadPLData(),
      _loadHistoryData(),
    ]);
  }

  // ==========================================
  // TAB 1: SHIFT HANDOVER LOGIC
  // ==========================================
  Future<void> _calculateShiftData() async {
    setState(() => _isLoadingShift = true);
    final opening = double.tryParse(_openingCashController.text.trim()) ?? 0.0;
    final actual = double.tryParse(_actualCashController.text.trim()) ?? 0.0;

    final summary = await DailyClosingService.calculateShiftSummary(
      shiftStart: _shiftStartTime,
      cashierName: _cashierNameController.text.trim().isNotEmpty ? _cashierNameController.text.trim() : 'الكاشير',
      openingCash: opening,
      actualCashCount: actual,
    );

    if (mounted) {
      setState(() {
        _shiftSummary = summary;
        _isLoadingShift = false;
      });
    }
  }

  void _addQuickCash(double amount) {
    final current = double.tryParse(_actualCashController.text.trim()) ?? 0.0;
    final updated = current + amount;
    _actualCashController.text = updated.toStringAsFixed(0);
    _calculateShiftData();
  }

  Future<void> _handleShiftFinishAndHandover() async {
    if (_shiftSummary == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.teal),
              SizedBox(width: 8),
              Text('تأكيد تسليم وإنهاء الوردية'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الكاشير: ${_shiftSummary!.cashierName}'),
              Text('إجمالي المبيعات: ${_shiftSummary!.totalSales.toStringAsFixed(0)} ر.ي'),
              Text('النقد المتوقع: ${_shiftSummary!.expectedCashInDrawer.toStringAsFixed(0)} ر.ي'),
              Text('العد الفعلي: ${_shiftSummary!.actualCashCount.toStringAsFixed(0)} ر.ي'),
              const Divider(height: 16),
              Text(
                _shiftSummary!.cashVariance.abs() < 0.01
                    ? 'الحالة: مطابق تماماً'
                    : (_shiftSummary!.cashVariance < 0
                        ? 'تنبيه: يوجد عجز قدره (${_shiftSummary!.cashVariance.abs().toStringAsFixed(0)} ر.ي)'
                        : 'تنبيه: توجد زيادة قدرها (+${_shiftSummary!.cashVariance.toStringAsFixed(0)} ر.ي)'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _shiftSummary!.cashVariance < -0.01 ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              const Text('هل تريد حفظ سجل الوردية وطباعة إيصال Z-Report الآن؟'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              icon: const Icon(Icons.print),
              label: const Text('حفظ وطباعة Z-Report'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isSavingShift = true);
      await DailyClosingService.saveShiftHandoverRecord(_shiftSummary!);
      await DailyClosingService.printShiftZReport(_shiftSummary!);

      // تصفير العد الفعلي وبدء وردية جديدة
      if (mounted) {
        setState(() {
          _shiftStartTime = DateTime.now();
          _actualCashController.text = '0';
          _isSavingShift = false;
        });
        await _loadAllTabs();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسليم الوردية وطباعة تقرير Z-Report بنجاح'), backgroundColor: Colors.teal),
        );
      }
    }
  }

  // ==========================================
  // TAB 2: P&L ADVANCED ANALYTICS LOGIC
  // ==========================================
  void _setPeriod(String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (period == 'today') {
      start = DateTime(now.year, now.month, now.day);
    } else if (period == 'yesterday') {
      final y = now.subtract(const Duration(days: 1));
      start = DateTime(y.year, y.month, y.day);
      end = DateTime(y.year, y.month, y.day, 23, 59, 59);
    } else if (period == 'week') {
      start = now.subtract(const Duration(days: 7));
    } else if (period == 'month') {
      start = DateTime(now.year, now.month, 1);
    } else {
      return;
    }

    setState(() {
      _selectedPeriodFilter = period;
      _plStartDate = start;
      _plEndDate = end;
    });
    _loadPLData();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _plStartDate, end: _plEndDate),
    );

    if (picked != null) {
      setState(() {
        _selectedPeriodFilter = 'custom';
        _plStartDate = picked.start;
        _plEndDate = picked.end;
      });
      _loadPLData();
    }
  }

  Future<void> _loadPLData() async {
    setState(() => _isLoadingPL = true);
    final summary = await DailyClosingService.getPeriodFinancialSummary(
      startDate: _plStartDate,
      endDate: _plEndDate,
    );
    if (mounted) {
      setState(() {
        _plSummary = summary;
        _isLoadingPL = false;
      });
    }
  }

  // ==========================================
  // TAB 3: CLOSING HISTORY & EXPORT
  // ==========================================
  Future<void> _loadHistoryData() async {
    setState(() => _isLoadingHistory = true);
    final todaySummary = await DailyClosingService.getTodaySummary();
    final db = sl<AppDatabase>();
    final history = await (db.select(db.dayClosings)..orderBy([(d) => drift.OrderingTerm.desc(d.createdAt)])).get();

    if (mounted) {
      setState(() {
        _todayClosingSummary = todaySummary;
        _previousClosings = history;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _performDailyClosing() async {
    setState(() => _isPerformingClosing = true);
    final path = await DailyClosingService.performDailyClosing(context);
    setState(() => _isPerformingClosing = false);

    if (mounted) {
      if (path != null) {
        await _loadHistoryData();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  const Text('تم إغلاق اليومية بنجاح'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تم حفظ وتصدير ملف تقرير اليومية ومزامنة النسخة الاحتياطية:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      path,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('حسنًا'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إتمام الإغلاق اليومي'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: Colors.amberAccent),
              SizedBox(width: 10),
              Text(
                'إغلاق اليومية، تقفيل الورديات والأرباح',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.amberAccent,
            indicatorWeight: 3,
            labelColor: Colors.amberAccent,
            unselectedLabelColor: Colors.grey.shade400,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(icon: Icon(Icons.access_time_filled_rounded), text: 'تقفيل الوردية الحالية (Z-Report)'),
              Tab(icon: Icon(Icons.analytics_rounded), text: 'لوحة الأرباح والخسائر المتقدمة (P&L)'),
              Tab(icon: Icon(Icons.archive_rounded), text: 'سجل وتقارير الإغلاقات السابقة'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث كافة البيانات',
              onPressed: _loadAllTabs,
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildShiftHandoverTab(),
            _buildProfitAndLossTab(),
            _buildHistoryAndArchiveTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGETS: TAB 1 (SHIFT HANDOVER & Z-REPORT)
  // ==========================================
  Widget _buildShiftHandoverTab() {
    if (_isLoadingShift) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = _shiftSummary;
    final isShortage = (summary?.cashVariance ?? 0) < -0.01;
    final isExcess = (summary?.cashVariance ?? 0) > 0.01;
    final isExact = !isShortage && !isExcess;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط معلومات الوردية العلوية
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_pin_circle_rounded, color: Colors.amber, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('الكاشير المناوب: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          Text(
                            _cashierNameController.text,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'بدء الوردية: ${DateFormat("yyyy-MM-dd HH:mm").format(_shiftStartTime)} | المدة: ${_formatDuration(DateTime.now().difference(_shiftStartTime))}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.white70),
                  label: const Text('تغيير وقت البدء', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_shiftStartTime),
                    );
                    if (time != null) {
                      setState(() {
                        _shiftStartTime = DateTime(
                          _shiftStartTime.year,
                          _shiftStartTime.month,
                          _shiftStartTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                      _calculateShiftData();
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // شبكة ملخص عمليات الوردية
          if (summary != null) ...[
            const Text(
              'تفاصيل المبيعات وطرق التحصيل خلال الوردية:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _buildStatCard('مبيعات نقدية (Cash)', '${summary.cashSales.toStringAsFixed(0)} ر.ي', 'نقد بالدرج', Icons.attach_money, Colors.green),
                _buildStatCard('مبيعات شبكة / بطاقة', '${summary.cardSales.toStringAsFixed(0)} ر.ي', 'تحصيل نقاط البيع', Icons.credit_card, Colors.blue),
                _buildStatCard('مبيعات محافظ إلكترونية', '${summary.walletSales.toStringAsFixed(0)} ر.ي', 'كريمي / جوالي / غيره', Icons.phone_android, Colors.deepPurple),
                _buildStatCard('مبيعات آجل (ديون)', '${summary.debtSales.toStringAsFixed(0)} ر.ي', 'سجل العملاء', Icons.receipt_long, Colors.amber.shade800),
                _buildStatCard('إجمالي مبيعات الوردية', '${summary.totalSales.toStringAsFixed(0)} ر.ي', '${summary.salesCount} عملية بيع', Icons.point_of_sale, Colors.teal),
                _buildStatCard('مصاريف نقدية مخرجة', '${summary.shiftExpenses.toStringAsFixed(0)} ر.ي', 'سحبيات نقدية بالوردية', Icons.money_off, Colors.redAccent),
                _buildStatCard('مرتجعات نقدية', '${summary.shiftReturns.toStringAsFixed(0)} ر.ي', 'فواتير مرتجعة', Icons.assignment_return, Colors.deepOrange),
                _buildStatCard('العهدة الافتتاحية', '${summary.openingCash.toStringAsFixed(0)} ر.ي', 'رصيد بداية الوردية', Icons.account_balance_wallet, Colors.indigo),
              ],
            ),

            const SizedBox(height: 24),

            // صندوق العد الفعلي والمطابقة
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate_rounded, color: Colors.teal, size: 24),
                      SizedBox(width: 8),
                      Text('العد الفعلي للنقدية ومطابقة الدرج (Cash Reconciliation)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // حقل العهدة الافتتاحية
                      Expanded(
                        child: TextField(
                          controller: _openingCashController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'العهدة الافتتاحية للدرج (ر.ي)',
                            prefixIcon: const Icon(Icons.login),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          onChanged: (_) => _calculateShiftData(),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // حقل العد الفعلي
                      Expanded(
                        child: TextField(
                          controller: _actualCashController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'إجمالي العد الفعلي للنقدية بالدرج (ر.ي)',
                            prefixIcon: const Icon(Icons.savings_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          onChanged: (_) => _calculateShiftData(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // أزرار الزيادة السريعة للعد
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('إضافة سريعة للعد الفعلي:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      _buildQuickCashChip(500),
                      _buildQuickCashChip(1000),
                      _buildQuickCashChip(5000),
                      _buildQuickCashChip(10000),
                      _buildQuickCashChip(50000),
                      OutlinedButton(
                        onPressed: () {
                          _actualCashController.text = '0';
                          _calculateShiftData();
                        },
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: const Text('تصفير', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // شريط نتيجة المطابقة والفارق
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('النقد المتوقع بالدرج آلياً', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              const SizedBox(height: 2),
                              Text(
                                '${summary.expectedCashInDrawer.toStringAsFixed(0)} ر.ي',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isExact
                                ? Colors.green.shade50
                                : (isShortage ? Colors.red.shade50 : Colors.blue.shade50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isExact
                                  ? Colors.green.shade300
                                  : (isShortage ? Colors.red.shade300 : Colors.blue.shade300),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isExact
                                  ? 'حالة الصندوق: مطابق تماماً'
                                  : (isShortage ? 'عجز في الصندوق (-)' : 'زيادة في الصندوق (+)'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isExact ? Colors.green.shade800 : (isShortage ? Colors.red.shade800 : Colors.blue.shade800),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${summary.cashVariance.abs().toStringAsFixed(0)} ر.ي',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isExact ? Colors.green.shade800 : (isShortage ? Colors.red.shade800 : Colors.blue.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // أزرار الإجراءات للوردية
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('معاينة وطباعة Z-Report للوردية'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => DailyClosingService.printShiftZReport(summary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: _isSavingShift
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('إنهاء وتسليم الوردية وطباعة التقرير', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isSavingShift ? null : _handleShiftFinishAndHandover,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickCashChip(double amount) {
    return ActionChip(
      label: Text('+${amount.toStringAsFixed(0)}'),
      backgroundColor: Colors.grey.shade100,
      onPressed: () => _addQuickCash(amount),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours ساعة و $minutes دقيقة';
    }
    return '$minutes دقيقة';
  }

  // ==========================================
  // WIDGETS: TAB 2 (ADVANCED P&L ANALYTICS)
  // ==========================================
  Widget _buildProfitAndLossTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط اختيار الفترة الزمنية
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.teal),
                const SizedBox(width: 10),
                const Text('تحديد الفترة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 16),
                _buildPeriodChoiceChip('اليوم', 'today'),
                const SizedBox(width: 8),
                _buildPeriodChoiceChip('أمس', 'yesterday'),
                const SizedBox(width: 8),
                _buildPeriodChoiceChip('آخر 7 أيام', 'week'),
                const SizedBox(width: 8),
                _buildPeriodChoiceChip('هذا الشهر', 'month'),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 16),
                  label: Text(_selectedPeriodFilter == 'custom'
                      ? '${DateFormat("MM/dd").format(_plStartDate)} - ${DateFormat("MM/dd").format(_plEndDate)}'
                      : 'فترة مخصصة...'),
                  backgroundColor: _selectedPeriodFilter == 'custom' ? Colors.teal.shade50 : Colors.grey.shade100,
                  side: BorderSide(color: _selectedPeriodFilter == 'custom' ? Colors.teal : Colors.grey.shade300),
                  onPressed: _pickCustomDateRange,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('طباعة تقرير PDF'),
                  onPressed: _plSummary != null ? () => DailyClosingService.printPeriodFinancialReport(_plSummary!) : null,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF107C41)),
                  icon: const Icon(Icons.table_view_rounded, size: 18),
                  label: const Text('تصدير Excel'),
                  onPressed: _plSummary != null
                      ? () async {
                          final path = await DailyClosingService.exportPeriodFinancialExcel(_plSummary!);
                          if (path != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم تصدير ملف الإكسل بنجاح إلى: $path'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_isLoadingPL)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_plSummary != null) ...[
            // بطاقات مؤشرات الأرباح والخسائر
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _buildStatCard(
                  'إجمالي المبيعات (Revenue)',
                  '${_plSummary!.totalSales.toStringAsFixed(0)} ر.ي',
                  '${_plSummary!.salesCount} عملية بيع خلال الفترة',
                  Icons.trending_up,
                  Colors.green.shade700,
                ),
                _buildStatCard(
                  'تكلفة البضاعة المباعة (COGS)',
                  '${_plSummary!.costOfGoodsSold.toStringAsFixed(0)} ر.ي',
                  'تكلفة الشراء الفعلية (FEFO)',
                  Icons.inventory_2_outlined,
                  Colors.blueGrey,
                ),
                _buildStatCard(
                  'إجمالي الربح (Gross Profit)',
                  '${_plSummary!.grossProfit.toStringAsFixed(0)} ر.ي',
                  'هامش إجمالي: ${_plSummary!.grossProfitMargin.toStringAsFixed(1)}%',
                  Icons.monetization_on_outlined,
                  Colors.teal,
                ),
                _buildStatCard(
                  'المصاريف التشغيلية',
                  '${_plSummary!.totalExpenses.toStringAsFixed(0)} ر.ي',
                  '${_plSummary!.expensesCount} عمليات صرف وسحبيات',
                  Icons.money_off,
                  Colors.redAccent,
                ),
                _buildStatCard(
                  'المرتجعات وتسديدات الموردين',
                  '${(_plSummary!.totalReturns + _plSummary!.totalVendorPayments).toStringAsFixed(0)} ر.ي',
                  'مرتجع: ${_plSummary!.totalReturns.toStringAsFixed(0)} | موردين: ${_plSummary!.totalVendorPayments.toStringAsFixed(0)}',
                  Icons.payments_outlined,
                  Colors.amber.shade800,
                ),
                _buildStatCard(
                  'صافي الربح الحقيقي (Net Profit)',
                  '${_plSummary!.netProfit.toStringAsFixed(0)} ر.ي',
                  'هامش صافي: ${_plSummary!.netProfitMargin.toStringAsFixed(1)}%',
                  Icons.stars_rounded,
                  _plSummary!.netProfit >= 0 ? Colors.indigo : Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // جدول الأصناف الأكثر ربحية
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.military_tech_rounded, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text('قائمة الأصناف الـ 10 الأكثر ربحية في هذه الفترة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_plSummary!.topProfitableMedicines.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('لا توجد مبيعات أصناف مسجلة في هذه الفترة', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    Table(
                      border: TableBorder(
                        horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(0.5),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(1.2),
                        6: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: const [
                            Padding(padding: EdgeInsets.all(10), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('اسم الصنف / الدواء', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('المبيعات', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('التكلفة', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('الربح الصافي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                            Padding(padding: EdgeInsets.all(10), child: Text('الهامش %', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                        ..._plSummary!.topProfitableMedicines.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final m = entry.value;
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text('$idx')),
                              Padding(padding: const EdgeInsets.all(10), child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${m.quantitySold}')),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${m.revenue.toStringAsFixed(0)} ر.ي')),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${m.cost.toStringAsFixed(0)} ر.ي')),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text('${m.profit.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: m.profitMargin > 20 ? Colors.green.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${m.profitMargin.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: m.profitMargin > 20 ? Colors.green.shade800 : Colors.amber.shade800)),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodChoiceChip(String label, String value) {
    final isSelected = _selectedPeriodFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.teal.shade100,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.teal.shade900 : Colors.black87,
      ),
      onSelected: (_) => _setPeriod(value),
    );
  }

  // ==========================================
  // WIDGETS: TAB 3 (CLOSING ARCHIVE & HISTORY)
  // ==========================================
  Widget _buildHistoryAndArchiveTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الإغلاق اليومي المباشر
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_clock_outlined, color: Colors.amber, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إغلاق اليومية الشامل مع الحفظ السحابي',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تاريخ اليوم: ${DateFormat("yyyy-MM-dd").format(DateTime.now())} | الوقت: ${DateFormat("HH:mm").format(DateTime.now())}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  icon: _isPerformingClosing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_alt),
                  label: const Text('تنفيذ إغلاق اليومية وتصدير الملف', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isPerformingClosing ? null : _performDailyClosing,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ملخص اليوم المالي السريع
          if (_todayClosingSummary != null) ...[
            const Text('مؤشرات اليوم الحاضر:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _buildStatCard('مبيعات اليوم', '${_todayClosingSummary!.totalSales.toStringAsFixed(0)} ر.ي', '${_todayClosingSummary!.salesCount} فواتير', Icons.point_of_sale, Colors.green),
                _buildStatCard('صافي أرباح اليوم', '${_todayClosingSummary!.netProfit.toStringAsFixed(0)} ر.ي', 'فارق البيع والشراء', Icons.trending_up, Colors.teal),
                _buildStatCard('النقدية الحالية بالصندوق', '${_todayClosingSummary!.cashInDrawer.toStringAsFixed(0)} ر.ي', 'المقبوضات - المصاريف', Icons.account_balance_wallet, Colors.blue),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // قائمة الإغلاقات السابقة
          const Text('سجل وأرشيف الإغلاقات والورديات السابقة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (_previousClosings.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('لا توجد تقارير إغلاق سابقة مسجلة')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _previousClosings.length,
              itemBuilder: (context, index) {
                final c = _previousClosings[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0F172A),
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    title: Text(
                      'إغلاق: ${DateFormat("yyyy-MM-dd HH:mm").format(c.createdAt)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'المبيعات: ${c.totalSales.toStringAsFixed(0)} ر.ي | الأرباح: ${c.netProfit.toStringAsFixed(0)} ر.ي | المصاريف: ${c.totalExpenses.toStringAsFixed(0)} ر.ي | النقدية: ${c.cashInDrawer.toStringAsFixed(0)} ر.ي',
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                    trailing: c.reportPdfPath != null
                        ? Tooltip(
                            message: 'مسار التقرير: ${c.reportPdfPath}',
                            child: const Icon(Icons.file_present_rounded, color: Colors.teal),
                          )
                        : null,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER CARD
  // ==========================================
  Widget _buildStatCard(String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.blueGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
