// نافذة إدارة وبدء واستئناف اليومية والوردية - PharmaOS
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/shift_manager_service.dart';
import '../../../../core/services/official_date_time_service.dart';

class ShiftStartDialog extends StatefulWidget {
  final bool isDismissible;
  const ShiftStartDialog({super.key, this.isDismissible = true});

  static Future<ActiveShiftModel?> show(BuildContext context, {bool isDismissible = true}) async {
    return showDialog<ActiveShiftModel>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => ShiftStartDialog(isDismissible: isDismissible),
    );
  }

  @override
  State<ShiftStartDialog> createState() => _ShiftStartDialogState();
}

class _ShiftStartDialogState extends State<ShiftStartDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _cashierNameController = TextEditingController(text: 'الكاشير المناوب');
  final _countedCashController = TextEditingController();
  final _varianceReasonController = TextEditingController();
  final _notesController = TextEditingController();

  double _expectedCash = 0.0;
  double _countedCash = 0.0;
  bool _isLoading = true;
  bool _isSaving = false;

  List<ShiftEmployeeAttendance> _workers = [];
  List<ActiveShiftModel> _unclosedShifts = [];

  StreamSubscription? _clockSubscription;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _clockSubscription = OfficialDateTimeService.secondStream.listen((dt) {
      if (mounted) setState(() => _currentTime = dt);
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final calculated = await ShiftManagerService.calculateSystemDrawerBalance();
    final workersList = await ShiftManagerService.getAvailableWorkers();
    final unclosed = await ShiftManagerService.getUnclosedShifts();

    if (mounted) {
      setState(() {
        _expectedCash = calculated;
        _countedCash = calculated;
        _countedCashController.text = calculated.toStringAsFixed(0);
        _workers = workersList;
        _unclosedShifts = unclosed;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _clockSubscription?.cancel();
    _tabController.dispose();
    _cashierNameController.dispose();
    _countedCashController.dispose();
    _varianceReasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _variance => _countedCash - _expectedCash;

  Future<void> _confirmStartNewShift() async {
    setState(() => _isSaving = true);
    try {
      final shift = await ShiftManagerService.startNewShift(
        expectedOpeningCash: _expectedCash,
        countedOpeningCash: _countedCash,
        cashierName: _cashierNameController.text.trim(),
        attendees: _workers,
        openingVarianceReason: _variance.abs() >= 1.0 ? _varianceReasonController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context, shift);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('تم بدء اليومية #${shift.shiftNumber} بنجاح وتوثيق رصيد الافتتاح ✅'),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resumeSelectedShift(ActiveShiftModel shift) async {
    setState(() => _isSaving = true);
    final resumed = await ShiftManagerService.resumeShift(shift.id);
    if (mounted) {
      Navigator.pop(context, resumed ?? shift);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استئناف اليومية #${shift.shiftNumber} بنجاح ومتابعة البيع 🔄'),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
          width: 780,
          constraints: const BoxConstraints(maxHeight: 740),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
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
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF38BDF8), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إدارة اليومية وبدء الوردية المحاسبية',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            OfficialDateTimeService.formatDateArabicWithDay(_currentTime),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Live Digital Clock
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled, color: Color(0xFF38BDF8), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            OfficialDateTimeService.formatLiveTime(_currentTime),
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isDismissible) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ],
                ),
              ),

              // Tabs
              Container(
                color: const Color(0xFF1E293B),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF38BDF8),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.wb_sunny_rounded, size: 20),
                      text: 'بدء يوم عمل جديد ☀️',
                    ),
                    Tab(
                      icon: const Icon(Icons.history_rounded, size: 20),
                      text: 'استئناف يومية غير مكتملة (${_unclosedShifts.length}) 🔄',
                    ),
                  ],
                ),
              ),

              // Body Content
              Flexible(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStartNewDayTab(),
                          _buildResumeDayTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartNewDayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. بطاقة رصيد الدرج والصندوق الافتتاحي
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
                    Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF38BDF8), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'مطابقة النقد في الدرج عند الافتتاح (Drawer Cash Count)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // النقد المحسوب بالنظام
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
                            const Text('النقد المحسوب بالنظام (الافتراضي)', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(
                              '${_expectedCash.toStringAsFixed(0)} ر.ي',
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
                          labelText: 'النقد الفعلي الموجود في الدرج',
                          labelStyle: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13),
                          suffixText: 'ر.ي',
                          suffixStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _countedCash = double.tryParse(val) ?? _expectedCash;
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
                                  ? 'تنبيه: يوجد عجز افتتاحي في الدرج قدره (${_variance.abs().toStringAsFixed(0)} ر.ي)'
                                  : 'تنبيه: توجد زيادة نقدية في الدرج قدرها (+${_variance.toStringAsFixed(0)} ر.ي)'),
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

                if (_variance.abs() >= 1.0) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _varianceReasonController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'سبب ومبرر الفارق الافتتاحي (اختياري)',
                      hintText: 'مثال: تسليم عهدة سابقة، مسحوبات مسائية...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. الكاشير المسؤول والملاحظات
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cashierNameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'اسم الكاشير / المسؤول عن الوردية',
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF38BDF8)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات الافتتاح (اختياري)',
                    prefixIcon: const Icon(Icons.edit_note, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. كشف حضور الموظفين للوردية
          Container(
            padding: const EdgeInsets.all(16),
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
                    Icon(Icons.how_to_reg_rounded, color: Color(0xFF38BDF8), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'الموظفون المناوبون والحاضرون في هذه الوردية',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _workers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final w = entry.value;
                    return FilterChip(
                      label: Text('${w.workerName} (${w.role})'),
                      selected: w.isPresent,
                      selectedColor: const Color(0xFF0284C7),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: w.isPresent ? Colors.white : Colors.white60,
                        fontSize: 12,
                        fontWeight: w.isPresent ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: const Color(0xFF0F172A),
                      onSelected: (selected) {
                        setState(() {
                          _workers[index] = ShiftEmployeeAttendance(
                            workerId: w.workerId,
                            workerName: w.workerName,
                            role: w.role,
                            isPresent: selected,
                          );
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // زر بدء اليومية
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.rocket_launch_rounded),
              label: const Text('تأكيد وبدء يومية العمل الرسمية 🚀', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving ? null : _confirmStartNewShift,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeDayTab() {
    if (_unclosedShifts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade400),
              const SizedBox(height: 12),
              const Text(
                'لا توجد أي يوميات غير مكتملة أو معلقة',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'كافة الورديات السابقة تم إغلاقها وترحيلها بنجاح. يمكنك بدء يوم جديد من التبويب الأول.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _unclosedShifts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final shift = _unclosedShifts[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF38BDF8), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'يومية وردية #${shift.shiftNumber}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('نشطة وغير مغلقة', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الكاشير: ${shift.cashierName} | بدأت في: ${OfficialDateTimeService.formatOfficialDateTime(shift.startTime)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      'الرصيد الافتتاحي: ${shift.countedOpeningCash.toStringAsFixed(0)} ر.ي',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('استئناف العمل'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : () => _resumeSelectedShift(shift),
              ),
            ],
          ),
        );
      },
    );
  }
}
