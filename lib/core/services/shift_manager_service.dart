// خدمة إدارة الورديات واليوميات وبداية ونهاية اليوم المحاسبي - PharmaOS
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;

import '../di/service_locator.dart';
import '../database/app_database.dart';
import 'official_date_time_service.dart';

class ShiftEmployeeAttendance {
  final int workerId;
  final String workerName;
  final String role;
  final bool isPresent;
  final String? note;

  const ShiftEmployeeAttendance({
    required this.workerId,
    required this.workerName,
    this.role = 'صيدلي',
    this.isPresent = true,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'worker_id': workerId,
        'worker_name': workerName,
        'role': role,
        'is_present': isPresent,
        'note': note,
      };

  factory ShiftEmployeeAttendance.fromJson(Map<String, dynamic> j) => ShiftEmployeeAttendance(
        workerId: j['worker_id'] as int? ?? 0,
        workerName: j['worker_name'] as String? ?? '',
        role: j['role'] as String? ?? 'صيدلي',
        isPresent: j['is_present'] as bool? ?? true,
        note: j['note'] as String?,
      );
}

class ActiveShiftModel {
  final String id;
  final int shiftNumber;
  final DateTime startTime;
  final String cashierName;
  final double expectedOpeningCash;
  final double countedOpeningCash;
  final double openingVariance;
  final String openingVarianceReason;
  final List<ShiftEmployeeAttendance> attendees;
  final String? notes;
  final bool isClosed;
  final DateTime? closedAt;

  const ActiveShiftModel({
    required this.id,
    required this.shiftNumber,
    required this.startTime,
    required this.cashierName,
    required this.expectedOpeningCash,
    required this.countedOpeningCash,
    required this.openingVariance,
    this.openingVarianceReason = '',
    required this.attendees,
    this.notes,
    this.isClosed = false,
    this.closedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'shift_number': shiftNumber,
        'start_time': startTime.toIso8601String(),
        'cashier_name': cashierName,
        'expected_opening_cash': expectedOpeningCash,
        'counted_opening_cash': countedOpeningCash,
        'opening_variance': openingVariance,
        'opening_variance_reason': openingVarianceReason,
        'attendees': attendees.map((a) => a.toJson()).toList(),
        'notes': notes,
        'is_closed': isClosed,
        'closed_at': closedAt?.toIso8601String(),
      };

  factory ActiveShiftModel.fromJson(Map<String, dynamic> j) => ActiveShiftModel(
        id: j['id'] as String? ?? 'shift-1',
        shiftNumber: j['shift_number'] as int? ?? 1,
        startTime: DateTime.tryParse(j['start_time']?.toString() ?? '') ?? DateTime.now(),
        cashierName: j['cashier_name'] as String? ?? 'الكاشير المناوب',
        expectedOpeningCash: (j['expected_opening_cash'] as num?)?.toDouble() ?? 0.0,
        countedOpeningCash: (j['counted_opening_cash'] as num?)?.toDouble() ?? 0.0,
        openingVariance: (j['opening_variance'] as num?)?.toDouble() ?? 0.0,
        openingVarianceReason: j['opening_variance_reason'] as String? ?? '',
        attendees: (j['attendees'] as List?)
                ?.map((e) => ShiftEmployeeAttendance.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        notes: j['notes'] as String?,
        isClosed: j['is_closed'] as bool? ?? false,
        closedAt: j['closed_at'] != null ? DateTime.tryParse(j['closed_at'].toString()) : null,
      );
}

class TopSellingItemInfo {
  final int medicineId;
  final String name;
  final int quantity;
  final double totalRevenue;

  const TopSellingItemInfo({
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.totalRevenue,
  });

  String get medicineName => name;
  int get quantitySold => quantity;
}

class LiveShiftStats {
  final DateTime shiftStart;
  final DateTime now;
  final int totalSalesCount;
  final double totalSalesAmount;
  final double totalCashSales;
  final double cardWalletSalesAmount;
  final double creditSalesAmount;
  final double totalReturnsAmount;
  final double totalExpensesAmount;
  final double totalVendorPaymentsAmount;
  final double openingCash;
  final double expectedCashInDrawer;
  final List<TopSellingItemInfo> topSellingItems;

  const LiveShiftStats({
    required this.shiftStart,
    required this.now,
    required this.totalSalesCount,
    required this.totalSalesAmount,
    required this.totalCashSales,
    required this.cardWalletSalesAmount,
    required this.creditSalesAmount,
    required this.totalReturnsAmount,
    required this.totalExpensesAmount,
    required this.totalVendorPaymentsAmount,
    required this.openingCash,
    required this.expectedCashInDrawer,
    required this.topSellingItems,
  });

  int get salesCount => totalSalesCount;
  double get cashSalesAmount => totalCashSales;
}

class ShiftClosingResult {
  final double actualCountedCash;
  final double expectedCash;
  final double variance;
  final double shortageAmount;
  final double surplusAmount;
  final String? varianceReason;
  final bool expenseVoucherCreated;

  const ShiftClosingResult({
    required this.actualCountedCash,
    required this.expectedCash,
    required this.variance,
    required this.shortageAmount,
    required this.surplusAmount,
    this.varianceReason,
    this.expenseVoucherCreated = false,
  });
}

class ShiftManagerService {
  static const String _prefActiveShiftKey = 'pharmaos_active_shift_v1';
  static const String _prefUnclosedShiftsKey = 'pharmaos_unclosed_shifts_v1';
  static const String _prefShiftSequence = 'pharmaos_shift_sequence_v1';

  static final ValueNotifier<ActiveShiftModel?> activeShiftNotifier = ValueNotifier<ActiveShiftModel?>(null);

  /// استرجاع الوردية النشطة من الذاكرة أو التخزين
  static Future<ActiveShiftModel?> getActiveShift() async {
    if (activeShiftNotifier.value != null && !activeShiftNotifier.value!.isClosed) {
      return activeShiftNotifier.value;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefActiveShiftKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final shift = ActiveShiftModel.fromJson(jsonDecode(raw));
        if (!shift.isClosed) {
          activeShiftNotifier.value = shift;
          return shift;
        }
      } catch (e) {
        debugPrint('Error decoding active shift: $e');
      }
    }
    return null;
  }

  /// جلب قائمة الورديات غير المكتملة السابقة لاستئنافها
  static Future<List<ActiveShiftModel>> getUnclosedShifts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefUnclosedShiftsKey) ?? [];
    final List<ActiveShiftModel> list = [];
    for (final str in rawList) {
      try {
        final s = ActiveShiftModel.fromJson(jsonDecode(str));
        if (!s.isClosed) {
          list.add(s);
        }
      } catch (_) {}
    }
    return list;
  }

  /// حساب الرصيد المتوقع حالياً في الصندوق/الدرج (آخر رصيد إغلاق أو الرصيد الحالي)
  static Future<double> calculateSystemDrawerBalance() async {
    try {
      final db = sl<AppDatabase>();
      // جلب جميع المبيعات النقدية والمصروفات والمدفوعات
      final sales = await (db.select(db.sales)..where((s) => s.status.equals('completed'))).get();
      final cashSales = sales
          .where((s) => s.paymentMethod == 'cash' || s.paymentMethod == 'نقدي')
          .fold<double>(0.0, (acc, s) => acc + s.totalAmount);

      final expenses = await db.select(db.expenses).get();
      final totalExpenses = expenses.fold<double>(0.0, (acc, e) => acc + e.amount);

      final vendorPayments = await db.select(db.vendorPayments).get();
      final totalVendorPayments = vendorPayments.fold<double>(0.0, (acc, v) => acc + v.amount);

      final returns = await db.select(db.returns).get();
      final totalReturns = returns.fold<double>(0.0, (acc, r) => acc + r.totalAmount);

      final netDrawer = cashSales - totalExpenses - totalVendorPayments - totalReturns;
      return netDrawer > 0 ? netDrawer : 0.0;
    } catch (e) {
      debugPrint('Error calculating drawer balance: $e');
      return 0.0;
    }
  }

  /// جلب قائمة الموظفين النشطين لتحديد الحضور
  static Future<List<ShiftEmployeeAttendance>> getAvailableWorkers() async {
    try {
      final db = sl<AppDatabase>();
      final workers = await (db.select(db.workers)..where((w) => w.isActive.equals(true))).get();
      if (workers.isEmpty) {
        return [
          const ShiftEmployeeAttendance(workerId: 1, workerName: 'الصيدلي العام', role: 'صيدلي مسؤول', isPresent: true),
        ];
      }
      return workers
          .map((w) => ShiftEmployeeAttendance(
                workerId: w.id,
                workerName: w.name,
                role: w.jobTitle ?? 'صيدلي',
                isPresent: true,
              ))
          .toList();
    } catch (_) {
      return [
        const ShiftEmployeeAttendance(workerId: 1, workerName: 'الصيدلي العام', role: 'صيدلي مسؤول', isPresent: true),
      ];
    }
  }

  /// بدء يوم ووردية جديدة وتوثيق رصيد الافتتاح وحضور الموظفين
  static Future<ActiveShiftModel> startNewShift({
    required double expectedOpeningCash,
    required double countedOpeningCash,
    required String cashierName,
    List<ShiftEmployeeAttendance> attendees = const [],
    String? openingVarianceReason,
    String? notes,
    DateTime? customStartTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final seq = (prefs.getInt(_prefShiftSequence) ?? 0) + 1;
    await prefs.setInt(_prefShiftSequence, seq);

    final startTime = customStartTime ?? DateTime.now();
    final variance = countedOpeningCash - expectedOpeningCash;

    final shift = ActiveShiftModel(
      id: 'shift-${DateTime.now().millisecondsSinceEpoch}',
      shiftNumber: seq,
      startTime: startTime,
      cashierName: cashierName.trim().isNotEmpty ? cashierName.trim() : 'الكاشير المناوب',
      expectedOpeningCash: expectedOpeningCash,
      countedOpeningCash: countedOpeningCash,
      openingVariance: variance,
      openingVarianceReason: openingVarianceReason ?? '',
      attendees: attendees,
      notes: notes,
      isClosed: false,
    );

    // 1. حفظ الوردية النشطة
    await prefs.setString(_prefActiveShiftKey, jsonEncode(shift.toJson()));

    // 2. إضافتها لقائمة الورديات غير المغلقة للحماية من فقدان البيانات عند الإغلاق المفاجئ
    final unclosedList = await getUnclosedShifts();
    unclosedList.removeWhere((s) => s.id == shift.id);
    unclosedList.insert(0, shift);
    await prefs.setStringList(
      _prefUnclosedShiftsKey,
      unclosedList.map((s) => jsonEncode(s.toJson())).toList(),
    );

    activeShiftNotifier.value = shift;

    // 3. توثيق حضور الموظفين في جدول worker_attendance
    if (attendees.isNotEmpty) {
      await _recordStaffAttendance(attendees, startTime);
    }

    // 4. إذا كان هناك عجز أو زيادة افتتاحية وتم تبريرها، توثيقها في القيود أو المصروفات
    if (variance.abs() >= 1.0 && openingVarianceReason != null && openingVarianceReason.isNotEmpty) {
      await _recordOpeningVarianceAdjustment(shift);
    }

    return shift;
  }

  /// تسجيل الحضور لطاقم العمل
  static Future<void> recordStaffAttendance(List<ShiftEmployeeAttendance> workers, {DateTime? date}) async {
    await _recordStaffAttendance(workers, date ?? DateTime.now());
  }

  /// استئناف يومية/وردية غير مكتملة
  static Future<ActiveShiftModel?> resumeShift(String shiftId) async {
    final unclosed = await getUnclosedShifts();
    final match = unclosed.where((s) => s.id == shiftId).firstOrNull;
    if (match != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefActiveShiftKey, jsonEncode(match.toJson()));
      activeShiftNotifier.value = match;
      return match;
    }
    return null;
  }

  /// حساب الإحصاءات الحية اللحظية للوردية الحالية
  static Future<LiveShiftStats> calculateLiveShiftStats({DateTime? shiftStartOverride}) async {
    final active = activeShiftNotifier.value ?? await getActiveShift();
    final start = shiftStartOverride ?? active?.startTime ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0);
    final now = DateTime.now();

    final db = sl<AppDatabase>();

    // 1. المبيعات
    final sales = await (db.select(db.sales)
          ..where((s) => s.createdAt.isBiggerOrEqualValue(start) & s.createdAt.isSmallerOrEqualValue(now) & s.status.equals('completed')))
        .get();

    int salesCount = sales.length;
    double totalSales = 0.0;
    double cashSales = 0.0;
    double cardWalletSales = 0.0;
    double creditSales = 0.0;

    for (final s in sales) {
      totalSales += s.totalAmount;
      final method = s.paymentMethod.toLowerCase();
      if (method == 'cash' || method == 'نقدي') {
        cashSales += s.totalAmount;
      } else if (method == 'debt' || method == 'آجل' || method == 'credit') {
        creditSales += s.totalAmount;
      } else {
        cardWalletSales += s.totalAmount;
      }
    }

    // 2. المرتجعات
    final returns = await (db.select(db.returns)
          ..where((r) => r.createdAt.isBiggerOrEqualValue(start) & r.createdAt.isSmallerOrEqualValue(now)))
        .get();
    double totalReturns = returns.fold<double>(0.0, (acc, r) => acc + r.totalAmount);

    // 3. المصروفات والسحبيات
    final expenses = await (db.select(db.expenses)
          ..where((e) => e.createdAt.isBiggerOrEqualValue(start) & e.createdAt.isSmallerOrEqualValue(now)))
        .get();
    double totalExpenses = expenses.fold<double>(0.0, (acc, e) => acc + e.amount);

    // 4. دفعات الموردين النقدية
    final vendorPayments = await (db.select(db.vendorPayments)
          ..where((v) => v.createdAt.isBiggerOrEqualValue(start) & v.createdAt.isSmallerOrEqualValue(now)))
        .get();
    double totalVendorPayments = vendorPayments.fold<double>(0.0, (acc, v) => acc + v.amount);

    // 5. النقد المتوقع في الدرج
    final openingCash = active?.countedOpeningCash ?? 0.0;
    final expectedCashInDrawer = openingCash + cashSales - totalExpenses - totalVendorPayments - totalReturns;

    // 6. أكثر الأدوية مبيعاً في هذه الوردية
    final saleIds = sales.map((s) => s.id).toList();
    final List<SaleItemRow> saleItems;
    if (saleIds.isNotEmpty) {
      saleItems = await (db.select(db.saleItems)..where((si) => si.saleId.isIn(saleIds))).get();
    } else {
      saleItems = [];
    }

    final Map<int, _ItemSalesAccumulator> medMap = {};
    for (final item in saleItems) {
      final acc = medMap.putIfAbsent(
        item.medicineId,
        () => _ItemSalesAccumulator(medicineId: item.medicineId, name: '', quantity: 0, revenue: 0.0),
      );
      acc.quantity += item.quantity;
      acc.revenue += item.total;
    }

    // تعبئة أسماء الأدوية
    final List<TopSellingItemInfo> topItems = [];
    final sortedAccs = medMap.values.toList()..sort((a, b) => b.quantity.compareTo(a.quantity));
    final topSublist = sortedAccs.take(6);

    for (final acc in topSublist) {
      final med = await (db.select(db.medicines)..where((m) => m.id.equals(acc.medicineId))).getSingleOrNull();
      topItems.add(TopSellingItemInfo(
        medicineId: acc.medicineId,
        name: med?.nameAr ?? 'دواء #${acc.medicineId}',
        quantity: acc.quantity,
        totalRevenue: acc.revenue,
      ));
    }

    return LiveShiftStats(
      shiftStart: start,
      now: now,
      totalSalesCount: salesCount,
      totalSalesAmount: totalSales,
      totalCashSales: cashSales,
      cardWalletSalesAmount: cardWalletSales,
      creditSalesAmount: creditSales,
      totalReturnsAmount: totalReturns,
      totalExpensesAmount: totalExpenses,
      totalVendorPaymentsAmount: totalVendorPayments,
      openingCash: openingCash,
      expectedCashInDrawer: expectedCashInDrawer > 0 ? expectedCashInDrawer : 0.0,
      topSellingItems: topItems,
    );
  }

  /// إتمام إغلاق الوردية واليومية وحفظ التقرير
  static Future<ShiftClosingResult> closeActiveShift({
    required double countedClosingCash,
    required double expectedClosingCash,
    String? varianceReason,
    bool createExpenseVoucherForDeficit = false,
  }) async {
    final actualCountedCash = countedClosingCash;
    final expectedCash = expectedClosingCash;
    final active = activeShiftNotifier.value ?? await getActiveShift();
    final variance = actualCountedCash - expectedCash;
    final shortageAmount = variance < -0.01 ? variance.abs() : 0.0;
    final surplusAmount = variance > 0.01 ? variance : 0.0;
    bool voucherCreated = false;

    final db = sl<AppDatabase>();

    // 1. إذا كان هناك عجز مالي ناتج عن مسحوبات منسية وتم اختيار تسجيلها، ننشئ سند صرف مصروف فوري
    if (shortageAmount > 0.5 && createExpenseVoucherForDeficit) {
      await db.into(db.expenses).insert(
        ExpensesCompanion.insert(
          category: 'تسوية عجز وردية',
          amount: shortageAmount,
          notes: drift.Value('تسوية عجز إغلاق وردية #${active?.shiftNumber ?? 1} - ${varianceReason ?? "مسحوبات غير مقيدة"}'),
        ),
      );
      voucherCreated = true;
    }

    // 2. حفظ سجل الإغلاق في جدول DayClosings
    final stats = await calculateLiveShiftStats();
    await db.into(db.dayClosings).insert(
      DayClosingsCompanion.insert(
        date: DateTime.now(),
        periodStart: stats.shiftStart,
        totalSales: stats.totalSalesAmount,
        totalReturns: stats.totalReturnsAmount,
        totalExpenses: stats.totalExpensesAmount,
        totalVendorPayments: stats.totalVendorPaymentsAmount,
        costOfGoodsSold: stats.totalSalesAmount * 0.75, // تقديري
        netProfit: (stats.totalSalesAmount - (stats.totalSalesAmount * 0.75) - stats.totalExpensesAmount),
        cashInDrawer: actualCountedCash,
      ),
    );

    // 3. إزالة الوردية من الورديات المفتوحة
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefActiveShiftKey);

    if (active != null) {
      final unclosed = await getUnclosedShifts();
      unclosed.removeWhere((s) => s.id == active.id);
      await prefs.setStringList(
        _prefUnclosedShiftsKey,
        unclosed.map((s) => jsonEncode(s.toJson())).toList(),
      );
    }

    activeShiftNotifier.value = null;

    return ShiftClosingResult(
      actualCountedCash: actualCountedCash,
      expectedCash: expectedCash,
      variance: variance,
      shortageAmount: shortageAmount,
      surplusAmount: surplusAmount,
      varianceReason: varianceReason,
      expenseVoucherCreated: voucherCreated,
    );
  }

  static Future<void> _recordStaffAttendance(List<ShiftEmployeeAttendance> attendees, DateTime date) async {
    try {
      final db = sl<AppDatabase>();
      for (final att in attendees) {
        await db.into(db.workerAttendance).insert(
          WorkerAttendanceCompanion.insert(
            workerId: att.workerId,
            attendanceDate: date,
            isAttended: drift.Value(att.isPresent),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error recording attendance: $e');
    }
  }

  static Future<void> _recordOpeningVarianceAdjustment(ActiveShiftModel shift) async {
    try {
      final db = sl<AppDatabase>();
      if (shift.openingVariance < -0.5) {
        await db.into(db.expenses).insert(
          ExpensesCompanion.insert(
            category: 'فوارق وتسويات افتتاحية',
            amount: shift.openingVariance.abs(),
            notes: drift.Value('تسوية عجز رصيد افتتاح: ${shift.openingVarianceReason}'),
          ),
        );
      }
    } catch (_) {}
  }
}

class _ItemSalesAccumulator {
  final int medicineId;
  String name;
  int quantity;
  double revenue;

  _ItemSalesAccumulator({
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}
