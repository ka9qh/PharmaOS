// خدمة إغلاق النوبة/اليومية - PharmaOS (مُصحَّحة)
//
// تصحيح مهم بعد ملاحظة المستخدم: هذه الخدمة تُصدر تقريرًا شاملاً (PDF+Excel)
// ونسخة احتياطية عند الضغط على "إغلاق اليومية"، لكنها **لا تقفل أي شيء**.
// لا يوجد أي رفض تلقائي لعمليات البيع/الشراء/المصاريف بعد الإغلاق. السبب:
// صيدليات تعمل 24 ساعة بنوبات متعددة، وكل عامل يحتاج إصدار تقرير عن فترته
// دون إيقاف عمل النظام للنوبة التالية.
//
// لهذا كل تقرير يغطي "الفترة منذ آخر إغلاق سابق وحتى الآن" (فترة نوبة) بدلاً
// من "اليوم التقويمي كاملاً من الصفر في كل مرة" - هذا أدق لمحاسبة كل نوبة عمل
// على حدة، ويسمح بعدة إغلاقات في نفس اليوم دون تكرار الأرقام.

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../features/inventory/domain/entities/inventory_entity.dart';
import 'stock_alert_service.dart';
import 'report_export_service.dart';
import 'backup_service.dart';

class DayClosingSummary {
  final DateTime createdAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalSales;
  final double totalReturns;
  final double totalExpenses;
  final double totalVendorPayments;
  final double costOfGoodsSold;
  final double netProfit;
  final double cashInDrawer;
  final List<StockSummary> lowStockItems;

  const DayClosingSummary({
    required this.createdAt,
    required this.periodStart,
    required this.periodEnd,
    required this.totalSales,
    required this.totalReturns,
    required this.totalExpenses,
    required this.totalVendorPayments,
    required this.costOfGoodsSold,
    required this.netProfit,
    required this.cashInDrawer,
    required this.lowStockItems,
  });
}

class DayClosingResult {
  final DayClosingSummary summary;
  final String? reportPdfPath;
  final String? reportExcelPath;
  final String? backupPath;

  const DayClosingResult({
    required this.summary,
    this.reportPdfPath,
    this.reportExcelPath,
    this.backupPath,
  });
}

class DayClosingService {
  final AppDatabase _db;
  final StockAlertService _stockAlertService;
  final ReportExportService _reportExportService;
  final BackupService _backupService;

  DayClosingService(
    this._db,
    this._stockAlertService,
    this._reportExportService,
    this._backupService,
  );

  /// بداية الفترة الحالية = وقت آخر إغلاق تم تسجيله (أي وقت، بغض النظر عن
  /// اليوم التقويمي)، أو بداية اليوم الحالي إذا لم يوجد أي إغلاق سابق إطلاقًا.
  Future<DateTime> _getCurrentPeriodStart() async {
    final lastClosing = await (_db.select(_db.dayClosings)
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
          ..limit(1))
        .getSingleOrNull();

    if (lastClosing != null) return lastClosing.createdAt;

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// وقت آخر إغلاق (لعرضه في الواجهة كمعلومة فقط - وليس لمنع أي شيء)
  Future<DateTime?> getLastClosingTime() async {
    final lastClosing = await (_db.select(_db.dayClosings)
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    return lastClosing?.createdAt;
  }

  Future<double> _sumSales(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.sales)
          ..where((s) => s.createdAt.isBetweenValues(start, end)))
        .get();
    return rows.fold<double>(0, (sum, s) => sum + s.totalAmount);
  }

  Future<double> _sumCustomerReturns(DateTime start, DateTime end) async {
    final row = await _db.customSelect(
      'SELECT IFNULL(SUM(ri.subtotal), 0) AS total '
      'FROM return_items ri '
      'JOIN returns r ON r.id = ri.return_id '
      'WHERE r.sale_id IS NOT NULL AND r.created_at BETWEEN ? AND ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {_db.returnItems, _db.returns},
    ).getSingle();
    return row.read<double>('total');
  }

  Future<double> _sumExpenses(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.expenses)
          ..where((e) => e.createdAt.isBetweenValues(start, end)))
        .get();
    return rows.fold<double>(0, (sum, e) => sum + e.amount);
  }

  Future<double> _sumVendorPayments(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.vendorPayments)
          ..where((v) => v.createdAt.isBetweenValues(start, end)))
        .get();
    return rows.fold<double>(0, (sum, v) => sum + v.amount);
  }

  Future<double> _sumCostOfGoodsSold(DateTime start, DateTime end) async {
    final row = await _db.customSelect(
      'SELECT IFNULL(SUM(si.quantity * IFNULL(b.purchase_price, 0)), 0) AS cogs '
      'FROM sale_items si '
      'JOIN sales s ON s.id = si.sale_id '
      'LEFT JOIN batches b ON b.id = si.batch_id '
      'WHERE s.created_at BETWEEN ? AND ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {_db.saleItems, _db.sales, _db.batches},
    ).getSingle();
    return row.read<double>('cogs');
  }

  // --- Helpers for Cash In Drawer calculation ---
  Future<double> _sumCashSales(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.sales)
          ..where((s) => s.createdAt.isBetweenValues(start, end))
          ..where((s) => s.paymentMethod.equals('نقدي')))
        .get();
    return rows.fold<double>(0, (sum, s) => sum + s.totalAmount);
  }

  Future<double> _sumCashCustomerPayments(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.customerPayments)
          ..where((c) => c.createdAt.isBetweenValues(start, end))
          ..where((c) => c.paymentMethod.equals('نقدي')))
        .get();
    return rows.fold<double>(0, (sum, c) => sum + c.amount);
  }

  Future<double> _sumCashVendorReturns(DateTime start, DateTime end) async {
    final row = await _db.customSelect(
      'SELECT IFNULL(SUM(total_amount), 0) AS total '
      'FROM returns '
      'WHERE purchase_id IS NOT NULL '
      'AND settlement_method = \'refund\' '
      'AND payment_method = \'نقدي\' '
      'AND created_at BETWEEN ? AND ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {_db.returns},
    ).getSingle();
    return row.read<double>('total');
  }

  Future<double> _sumCashCustomerReturns(DateTime start, DateTime end) async {
    final row = await _db.customSelect(
      'SELECT IFNULL(SUM(total_amount), 0) AS total '
      'FROM returns '
      'WHERE sale_id IS NOT NULL '
      'AND settlement_method = \'refund\' '
      'AND payment_method = \'نقدي\' '
      'AND created_at BETWEEN ? AND ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {_db.returns},
    ).getSingle();
    return row.read<double>('total');
  }

  Future<double> _sumCashExpenses(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.expenses)
          ..where((e) => e.createdAt.isBetweenValues(start, end))
          ..where((e) => e.paymentMethod.equals('نقدي')))
        .get();
    return rows.fold<double>(0, (sum, e) => sum + e.amount);
  }

  Future<double> _sumCashVendorPayments(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.vendorPayments)
          ..where((v) => v.createdAt.isBetweenValues(start, end))
          ..where((v) => v.paymentMethod.equals('نقدي')))
        .get();
    return rows.fold<double>(0, (sum, v) => sum + v.amount);
  }

  Future<double> _sumCashPurchases(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.purchases)
          ..where((p) => p.createdAt.isBetweenValues(start, end))
          ..where((p) => p.paymentMethod.equals('نقدي')))
        .get();
    return rows.fold<double>(0, (sum, p) => sum + p.paidAmount);
  }

  /// معاينة حية لأرقام الفترة الحالية (منذ آخر إغلاق) - للعرض قبل الضغط على الزر
  Future<DayClosingSummary> computeCurrentPeriodSummary() async {
    final periodStart = await _getCurrentPeriodStart();
    final periodEnd = DateTime.now();

    final totalSales = await _sumSales(periodStart, periodEnd);
    final totalReturns = await _sumCustomerReturns(periodStart, periodEnd);
    final totalExpenses = await _sumExpenses(periodStart, periodEnd);
    final totalVendorPayments = await _sumVendorPayments(periodStart, periodEnd);
    final costOfGoodsSold = await _sumCostOfGoodsSold(periodStart, periodEnd);

    final netSales = totalSales - totalReturns;
    final netProfit = netSales - (costOfGoodsSold + totalExpenses);

    final cashSales = await _sumCashSales(periodStart, periodEnd);
    final cashCustomerPayments = await _sumCashCustomerPayments(periodStart, periodEnd);
    final cashVendorReturns = await _sumCashVendorReturns(periodStart, periodEnd);

    final cashCustomerReturns = await _sumCashCustomerReturns(periodStart, periodEnd);
    final cashExpenses = await _sumCashExpenses(periodStart, periodEnd);
    final cashVendorPayments = await _sumCashVendorPayments(periodStart, periodEnd);
    final cashPurchases = await _sumCashPurchases(periodStart, periodEnd);

    final totalCashIn = cashSales + cashCustomerPayments + cashVendorReturns;
    final totalCashOut = cashCustomerReturns + cashExpenses + cashVendorPayments + cashPurchases;

    final cashInDrawer = totalCashIn - totalCashOut;

    final lowStockItems = await _stockAlertService.getLowStockItems();

    return DayClosingSummary(
      createdAt: DateTime.now(),
      periodStart: periodStart,
      periodEnd: periodEnd,
      totalSales: totalSales,
      totalReturns: totalReturns,
      totalExpenses: totalExpenses,
      totalVendorPayments: totalVendorPayments,
      costOfGoodsSold: costOfGoodsSold,
      netProfit: netProfit,
      cashInDrawer: cashInDrawer,
      lowStockItems: lowStockItems,
    );
  }

  /// ينفذ الإغلاق فعليًا: يحسب فترة النوبة الحالية، ينشئ نسخة احتياطية وتقريرين
  /// (PDF/Excel)، ويحفظ Snapshot دون قفل أي شيء لاحقًا. يمكن استدعاؤه عدة مرات
  /// في نفس اليوم التقويمي (نوبات متعددة) بلا أي مشكلة.
  Future<DayClosingResult> closeCurrentPeriod({required int? closedByUserId}) async {
    final summary = await computeCurrentPeriodSummary();
    final now = DateTime.now();
    final calendarDate = DateTime(now.year, now.month, now.day);

    final backupPath = await _backupService.createBackup();
    final pdfPath = await _reportExportService.generatePdf(summary);
    final excelPath = await _reportExportService.generateExcel(summary);

    await _db.into(_db.dayClosings).insert(
          DayClosingsCompanion.insert(
            date: calendarDate,
            periodStart: summary.periodStart,
            totalSales: summary.totalSales,
            totalReturns: summary.totalReturns,
            totalExpenses: summary.totalExpenses,
            totalVendorPayments: summary.totalVendorPayments,
            costOfGoodsSold: summary.costOfGoodsSold,
            netProfit: summary.netProfit,
            cashInDrawer: summary.cashInDrawer,
            closedBy: Value(closedByUserId),
            reportPdfPath: Value(pdfPath),
            reportExcelPath: Value(excelPath),
            backupPath: Value(backupPath),
          ),
        );

    return DayClosingResult(
      summary: summary,
      reportPdfPath: pdfPath,
      reportExcelPath: excelPath,
      backupPath: backupPath,
    );
  }

  Future<List<DayClosingRow>> listRecent({int limit = 30}) {
    return (_db.select(_db.dayClosings)
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
          ..limit(limit))
        .get();
  }

  /// حذف تقرير إغلاق خاطئ (وليس "إعادة فتح يوم" - لا يوجد شيء مُقفل أصلًا).
  /// محمي بصلاحية على مستوى الواجهة (Owner/Manager)، ويُسجَّل في Audit Log من المستدعي.
  Future<void> deleteClosingRecord(int id) async {
    await (_db.delete(_db.dayClosings)..where((d) => d.id.equals(id))).go();
  }
}
