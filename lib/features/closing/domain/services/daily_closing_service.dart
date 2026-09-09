// خدمة إغلاق اليومية، تقفيل الورديات، والأرباح والخسائر المتقدمة - PharmaOS
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xls;
import 'package:drift/drift.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../../core/services/cloud_backup_service.dart';
import 'package:printing/printing.dart';

class ProfitableMedicineItem {
  final String name;
  final int quantitySold;
  final double revenue;
  final double cost;
  final double profit;
  final double profitMargin;

  const ProfitableMedicineItem({
    required this.name,
    required this.quantitySold,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.profitMargin,
  });
}

class FinancialPeriodSummary {
  final DateTime startDate;
  final DateTime endDate;
  final double totalSales;
  final int salesCount;
  final double costOfGoodsSold;
  final double grossProfit;
  final double grossProfitMargin;
  final double totalExpenses;
  final int expensesCount;
  final double totalReturns;
  final double totalVendorPayments;
  final double netProfit;
  final double netProfitMargin;
  final Map<String, double> paymentMethodsBreakdown;
  final List<ProfitableMedicineItem> topProfitableMedicines;

  const FinancialPeriodSummary({
    required this.startDate,
    required this.endDate,
    required this.totalSales,
    required this.salesCount,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.grossProfitMargin,
    required this.totalExpenses,
    required this.expensesCount,
    required this.totalReturns,
    required this.totalVendorPayments,
    required this.netProfit,
    required this.netProfitMargin,
    required this.paymentMethodsBreakdown,
    required this.topProfitableMedicines,
  });
}

class ShiftHandoverSummary {
  final DateTime shiftStart;
  final DateTime shiftEnd;
  final String cashierName;
  final double openingCash;
  final double cashSales;
  final double cardSales;
  final double walletSales;
  final double debtSales;
  final double totalSales;
  final int salesCount;
  final double shiftExpenses;
  final double shiftReturns;
  final double expectedCashInDrawer;
  final double actualCashCount;
  final double cashVariance; // الزيادة (+) أو العجز (-)

  const ShiftHandoverSummary({
    required this.shiftStart,
    required this.shiftEnd,
    required this.cashierName,
    required this.openingCash,
    required this.cashSales,
    required this.cardSales,
    required this.walletSales,
    required this.debtSales,
    required this.totalSales,
    required this.salesCount,
    required this.shiftExpenses,
    required this.shiftReturns,
    required this.expectedCashInDrawer,
    required this.actualCashCount,
    required this.cashVariance,
  });
}

class DailyClosingSummary {
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final double totalVendorPayments;
  final double costOfGoodsSold;
  final double netProfit;
  final double cashInDrawer;
  final int salesCount;
  final int purchasesCount;
  final int expensesCount;
  final Map<String, double> paymentMethodsBreakdown;

  const DailyClosingSummary({
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.totalVendorPayments,
    required this.costOfGoodsSold,
    required this.netProfit,
    required this.cashInDrawer,
    required this.salesCount,
    required this.purchasesCount,
    required this.expensesCount,
    required this.paymentMethodsBreakdown,
  });
}

class DailyClosingService {
  /// جلب ملخص العمليات المالية لليوم من قاعدة البيانات مباشرة
  static Future<DailyClosingSummary> getTodaySummary() async {
    final db = sl<AppDatabase>();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // 1. المبيعات
    final sales = await (db.select(db.sales)
          ..where((s) => s.createdAt.isBiggerOrEqualValue(startOfToday)))
        .get();
    final totalSales = sales.fold<double>(0, (sum, s) => sum + s.totalAmount);

    // حساب طرق الدفع للمبيعات
    final paymentMethods = <String, double>{};
    for (var s in sales) {
      paymentMethods[s.paymentMethod] = (paymentMethods[s.paymentMethod] ?? 0) + s.totalAmount;
    }

    // 2. تكلفة البضاعة المباعة والأرباح
    final saleIds = sales.map((s) => s.id).toList();
    double totalCost = 0;
    if (saleIds.isNotEmpty) {
      final saleItems = await (db.select(db.saleItems)..where((si) => si.saleId.isIn(saleIds))).get();
      for (var item in saleItems) {
        if (item.batchId != null) {
          final batch = await (db.select(db.batches)..where((b) => b.id.equals(item.batchId!))).getSingleOrNull();
          if (batch != null) {
            totalCost += (batch.purchasePrice * item.quantity);
          } else {
            totalCost += (item.unitPrice * 0.8 * item.quantity);
          }
        } else {
          totalCost += (item.unitPrice * 0.8 * item.quantity);
        }
      }
    }
    final netProfit = totalSales - totalCost;

    // 3. المشتريات
    final purchases = await (db.select(db.purchases)
          ..where((p) => p.createdAt.isBiggerOrEqualValue(startOfToday)))
        .get();
    final totalPurchases = purchases.fold<double>(0, (sum, p) => sum + p.totalAmount);

    // 4. المصاريف
    final expenses = await (db.select(db.expenses)
          ..where((e) => e.createdAt.isBiggerOrEqualValue(startOfToday)))
        .get();
    final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    // 5. تسديدات الموردين
    final vendorPayments = await (db.select(db.vendorPayments)
          ..where((vp) => vp.createdAt.isBiggerOrEqualValue(startOfToday)))
        .get();
    final totalVendorPayments = vendorPayments.fold<double>(0, (sum, vp) => sum + vp.amount);

    // 6. النقدية في الصندوق
    final cashSales = paymentMethods['نقدي'] ?? 0;
    final cashExpenses = expenses.where((e) => e.paymentMethod == 'نقدي').fold<double>(0, (sum, e) => sum + e.amount);
    final cashVendorPayments = vendorPayments.where((vp) => vp.paymentMethod == 'نقدي').fold<double>(0, (sum, vp) => sum + vp.amount);
    final cashInDrawer = cashSales - cashExpenses - cashVendorPayments;

    return DailyClosingSummary(
      totalSales: totalSales,
      totalPurchases: totalPurchases,
      totalExpenses: totalExpenses,
      totalVendorPayments: totalVendorPayments,
      costOfGoodsSold: totalCost,
      netProfit: netProfit > 0 ? netProfit : 0,
      cashInDrawer: cashInDrawer > 0 ? cashInDrawer : 0,
      salesCount: sales.length,
      purchasesCount: purchases.length,
      expensesCount: expenses.length,
      paymentMethodsBreakdown: paymentMethods,
    );
  }

  /// حساب ملخص الأرباح والخسائر الشامل لفترة مخصصة مع تحليل الأصناف
  static Future<FinancialPeriodSummary> getPeriodFinancialSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = sl<AppDatabase>();
    final endInclusive = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    // المبيعات في الفترة
    final sales = await (db.select(db.sales)
          ..where((s) => s.createdAt.isBiggerOrEqualValue(startDate) & s.createdAt.isSmallerOrEqualValue(endInclusive)))
        .get();

    final totalSales = sales.fold<double>(0, (sum, s) => sum + s.totalAmount);
    final paymentMethods = <String, double>{};
    for (var s in sales) {
      paymentMethods[s.paymentMethod] = (paymentMethods[s.paymentMethod] ?? 0) + s.totalAmount;
    }

    // حساب تكلفة البضاعة المباعة وتحليل الأصناف
    double costOfGoodsSold = 0.0;
    final Map<int, Map<String, dynamic>> medProfitMap = {};

    final saleIds = sales.map((s) => s.id).toList();
    if (saleIds.isNotEmpty) {
      final saleItems = await (db.select(db.saleItems)..where((si) => si.saleId.isIn(saleIds))).get();
      for (var it in saleItems) {
        double itemCost = 0.0;
        if (it.batchId != null) {
          final b = await (db.select(db.batches)..where((x) => x.id.equals(it.batchId!))).getSingleOrNull();
          itemCost = (b?.purchasePrice ?? (it.unitPrice * 0.8)) * it.quantity;
        } else {
          itemCost = (it.unitPrice * 0.8) * it.quantity;
        }
        costOfGoodsSold += itemCost;

        if (!medProfitMap.containsKey(it.medicineId)) {
          final med = await (db.select(db.medicines)..where((m) => m.id.equals(it.medicineId))).getSingleOrNull();
          medProfitMap[it.medicineId] = {
            'name': med?.nameAr ?? 'صنف #${it.medicineId}',
            'qty': 0,
            'revenue': 0.0,
            'cost': 0.0,
          };
        }

        medProfitMap[it.medicineId]!['qty'] = (medProfitMap[it.medicineId]!['qty'] as int) + it.quantity;
        medProfitMap[it.medicineId]!['revenue'] = (medProfitMap[it.medicineId]!['revenue'] as double) + (it.total > 0 ? it.total : it.subtotal);
        medProfitMap[it.medicineId]!['cost'] = (medProfitMap[it.medicineId]!['cost'] as double) + itemCost;
      }
    }

    final grossProfit = totalSales - costOfGoodsSold;
    final grossProfitMargin = totalSales > 0 ? (grossProfit / totalSales) * 100 : 0.0;

    // المصاريف
    final expenses = await (db.select(db.expenses)
          ..where((e) => e.createdAt.isBiggerOrEqualValue(startDate) & e.createdAt.isSmallerOrEqualValue(endInclusive)))
        .get();
    final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    // المرتجعات
    final returns = await (db.select(db.returns)
          ..where((r) => r.createdAt.isBiggerOrEqualValue(startDate) & r.createdAt.isSmallerOrEqualValue(endInclusive)))
        .get();
    final totalReturns = returns.fold<double>(0, (sum, r) => sum + r.totalAmount);

    // تسديدات الموردين
    final vendorPayments = await (db.select(db.vendorPayments)
          ..where((vp) => vp.createdAt.isBiggerOrEqualValue(startDate) & vp.createdAt.isSmallerOrEqualValue(endInclusive)))
        .get();
    final totalVendorPayments = vendorPayments.fold<double>(0, (sum, vp) => sum + vp.amount);

    // صافي الأرباح
    final netProfit = grossProfit - totalExpenses;
    final netProfitMargin = totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;

    // تجميع الأصناف الأكثر ربحية
    final List<ProfitableMedicineItem> topProfitable = [];
    for (var entry in medProfitMap.values) {
      final rev = entry['revenue'] as double;
      final cst = entry['cost'] as double;
      final prf = rev - cst;
      final margin = rev > 0 ? (prf / rev) * 100 : 0.0;
      topProfitable.add(ProfitableMedicineItem(
        name: entry['name'] as String,
        quantitySold: entry['qty'] as int,
        revenue: rev,
        cost: cst,
        profit: prf,
        profitMargin: margin,
      ));
    }
    topProfitable.sort((a, b) => b.profit.compareTo(a.profit));

    return FinancialPeriodSummary(
      startDate: startDate,
      endDate: endDate,
      totalSales: totalSales,
      salesCount: sales.length,
      costOfGoodsSold: costOfGoodsSold,
      grossProfit: grossProfit,
      grossProfitMargin: grossProfitMargin,
      totalExpenses: totalExpenses,
      expensesCount: expenses.length,
      totalReturns: totalReturns,
      totalVendorPayments: totalVendorPayments,
      netProfit: netProfit,
      netProfitMargin: netProfitMargin,
      paymentMethodsBreakdown: paymentMethods,
      topProfitableMedicines: topProfitable.take(10).toList(),
    );
  }

  /// حساب تقفيل الوردية الحالية للكاشير
  static Future<ShiftHandoverSummary> calculateShiftSummary({
    required DateTime shiftStart,
    required String cashierName,
    required double openingCash,
    required double actualCashCount,
  }) async {
    final db = sl<AppDatabase>();
    final shiftEnd = DateTime.now();

    // مبيعات الوردية
    final sales = await (db.select(db.sales)
          ..where((s) => s.createdAt.isBiggerOrEqualValue(shiftStart) & s.createdAt.isSmallerOrEqualValue(shiftEnd)))
        .get();

    double cashSales = 0.0;
    double cardSales = 0.0;
    double walletSales = 0.0;
    double debtSales = 0.0;
    double totalSales = 0.0;

    for (var s in sales) {
      totalSales += s.totalAmount;
      final pMethod = s.paymentMethod.toLowerCase();
      if (pMethod.contains('نقد') || pMethod.contains('cash')) {
        cashSales += s.totalAmount;
      } else if (pMethod.contains('شبك') || pMethod.contains('بطاق') || pMethod.contains('card')) {
        cardSales += s.totalAmount;
      } else if (pMethod.contains('محفظ') || pMethod.contains('wallet')) {
        walletSales += s.totalAmount;
      } else {
        debtSales += s.totalAmount;
      }
    }

    // مصاريف الوردية النقدية
    final expenses = await (db.select(db.expenses)
          ..where((e) => e.createdAt.isBiggerOrEqualValue(shiftStart) & e.createdAt.isSmallerOrEqualValue(shiftEnd)))
        .get();
    final shiftExpenses = expenses.where((e) => e.paymentMethod == 'نقدي').fold<double>(0, (sum, e) => sum + e.amount);

    // مرتجعات الوردية النقدية
    final returns = await (db.select(db.returns)
          ..where((r) => r.createdAt.isBiggerOrEqualValue(shiftStart) & r.createdAt.isSmallerOrEqualValue(shiftEnd)))
        .get();
    final shiftReturns = returns.fold<double>(0, (sum, r) => sum + r.totalAmount);

    // النقد المتوقع في الدرج = العهدة الافتتاحية + المبيعات النقدية - المصاريف النقدية - المرتجعات
    final expectedCashInDrawer = openingCash + cashSales - shiftExpenses - shiftReturns;
    final cashVariance = actualCashCount - expectedCashInDrawer;

    return ShiftHandoverSummary(
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      cashierName: cashierName,
      openingCash: openingCash,
      cashSales: cashSales,
      cardSales: cardSales,
      walletSales: walletSales,
      debtSales: debtSales,
      totalSales: totalSales,
      salesCount: sales.length,
      shiftExpenses: shiftExpenses,
      shiftReturns: shiftReturns,
      expectedCashInDrawer: expectedCashInDrawer,
      actualCashCount: actualCashCount,
      cashVariance: cashVariance,
    );
  }

  /// تنفيذ إغلاق اليومية وتصدير الملف وحفظه
  static Future<String?> performDailyClosing(BuildContext? context) async {
    try {
      final summary = await getTodaySummary();
      final settings = await sl<SettingsRepository>().load();
      final targetDirectoryPath = settings.savePath.isNotEmpty ? settings.savePath : 'C:\\PharmaOS_Closings';

      final dir = Directory(targetDirectoryPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      String savedFilePath = '';

      if (settings.saveFormat.toUpperCase() == 'EXCEL') {
        final excel = xls.Excel.createExcel();
        final sheet = excel['تقرير الإغلاق اليومي'];
        excel.delete('Sheet1');

        sheet.appendRow([xls.TextCellValue('تقرير الإغلاق اليومي - ${settings.pharmacyName}')]);
        sheet.appendRow([xls.TextCellValue('التاريخ: ${DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now())}')]);
        sheet.appendRow([xls.TextCellValue('')]);
        sheet.appendRow([xls.TextCellValue('البند'), xls.TextCellValue('القيمة (ريال يمني)')]);
        sheet.appendRow([xls.TextCellValue('إجمالي المبيعات'), xls.TextCellValue(summary.totalSales.toStringAsFixed(0))]);
        sheet.appendRow([xls.TextCellValue('تكلفة البضاعة المباعة'), xls.TextCellValue(summary.costOfGoodsSold.toStringAsFixed(0))]);
        sheet.appendRow([xls.TextCellValue('صافي أرباح اليوم'), xls.TextCellValue(summary.netProfit.toStringAsFixed(0))]);
        sheet.appendRow([xls.TextCellValue('إجمالي المشتريات'), xls.TextCellValue(summary.totalPurchases.toStringAsFixed(0))]);
        sheet.appendRow([xls.TextCellValue('إجمالي المصاريف والسحبيات'), xls.TextCellValue(summary.totalExpenses.toStringAsFixed(0))]);
        sheet.appendRow([xls.TextCellValue('تسديدات الموردين'), xls.TextCellValue(summary.totalVendorPayments.toStringAsFixed(0))]);
        sheet.appendRow([xls.TextCellValue('النقدية الفعلية بالصندوق'), xls.TextCellValue(summary.cashInDrawer.toStringAsFixed(0))]);

        final fileBytes = excel.save();
        if (fileBytes != null) {
          final file = File('${dir.path}\\DailyClosing_$dateStr.xlsx');
          await file.writeAsBytes(fileBytes);
          savedFilePath = file.path;
        }
      } else {
        final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
        final ttf = pw.Font.ttf(fontData);
        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(base: ttf),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text('تقرير إغلاق اليومية', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Center(
                    child: pw.Text(settings.pharmacyName, style: const pw.TextStyle(fontSize: 14)),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('التاريخ: ${DateFormat("yyyy-MM-dd").format(DateTime.now())} | الوقت: ${DateFormat("HH:mm:ss").format(DateTime.now())}'),
                  pw.Divider(),
                  pw.SizedBox(height: 12),
                  pw.Text('الملخص المالي الشامل:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    headers: ['البند المالي', 'القيمة بالريال'],
                    data: [
                      ['إجمالي المبيعات', '${summary.totalSales.toStringAsFixed(0)} ر.ي (${summary.salesCount} فاتورة)'],
                      ['تكلفة البضاعة المباعة', '${summary.costOfGoodsSold.toStringAsFixed(0)} ر.ي'],
                      ['صافي الربح الفعلي', '${summary.netProfit.toStringAsFixed(0)} ر.ي'],
                      ['إجمالي المشتريات', '${summary.totalPurchases.toStringAsFixed(0)} ر.ي (${summary.purchasesCount} فاتورة)'],
                      ['إجمالي المصاريف', '${summary.totalExpenses.toStringAsFixed(0)} ر.ي (${summary.expensesCount} عملية)'],
                      ['تسديدات الموردين', '${summary.totalVendorPayments.toStringAsFixed(0)} ر.ي'],
                      ['النقدية المتبقية بالصندوق', '${summary.cashInDrawer.toStringAsFixed(0)} ر.ي'],
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text('تفصيل المبيعات حسب طرق الدفع:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  ...summary.paymentMethodsBreakdown.entries.map(
                    (e) => pw.Text('• ${e.key}: ${e.value.toStringAsFixed(0)} ر.ي'),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Text('تم إنشاء هذا التقرير آلياً بواسطة نظام PharmaOS المتكامل.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                ],
              );
            },
          ),
        );

        final file = File('${dir.path}\\DailyClosing_$dateStr.pdf');
        await file.writeAsBytes(await pdf.save());
        savedFilePath = file.path;
      }

      final db = sl<AppDatabase>();
      await db.into(db.dayClosings).insert(
            DayClosingsCompanion.insert(
              date: DateTime.now(),
              periodStart: DateTime.now().subtract(const Duration(hours: 24)),
              totalSales: summary.totalSales,
              totalReturns: 0,
              totalExpenses: summary.totalExpenses,
              totalVendorPayments: summary.totalVendorPayments,
              costOfGoodsSold: summary.costOfGoodsSold,
              netProfit: summary.netProfit,
              cashInDrawer: summary.cashInDrawer,
              reportPdfPath: Value(savedFilePath),
            ),
          );

      Future.microtask(() async {
        try {
          await CloudBackupService.triggerBackgroundAutoSync(forceClosing: true);
        } catch (_) {}
      });

      return savedFilePath;
    } catch (e) {
      debugPrint('❌ خطأ أثناء إغلاق اليومية: $e');
      return null;
    }
  }

  /// طباعة تقرير تقفيل الوردية Z-Report (بصيغة إيصال حراري 80mm أو A4)
  static Future<void> printShiftZReport(ShiftHandoverSummary summary) async {
    try {
      final settings = await sl<SettingsRepository>().load();
      final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(10),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: ttf),
          build: (pw.Context ctx) {
            final isBalanced = summary.cashVariance.abs() < 0.01;
            final isShortage = summary.cashVariance < -0.01;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    settings.pharmacyName.isNotEmpty ? settings.pharmacyName : 'PharmaOS',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text('تقرير تقفيل وردية الكاشير (Z-Report)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),
                pw.Text('الكاشير: ${summary.cashierName}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('بدء الوردية: ${DateFormat("yyyy-MM-dd HH:mm").format(summary.shiftStart)}', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('نهاية الوردية: ${DateFormat("yyyy-MM-dd HH:mm").format(summary.shiftEnd)}', style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(thickness: 0.5),

                pw.SizedBox(height: 4),
                pw.Text('تفاصيل العمليات والمبيعات:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                _buildReceiptRow('عهدة بداية الوردية:', '${summary.openingCash.toStringAsFixed(0)} ر.ي'),
                _buildReceiptRow('مبيعات نقدية (Cash):', '${summary.cashSales.toStringAsFixed(0)} ر.ي'),
                _buildReceiptRow('مبيعات شبكة / بطاقات:', '${summary.cardSales.toStringAsFixed(0)} ر.ي'),
                _buildReceiptRow('مبيعات محافظ إلكترونية:', '${summary.walletSales.toStringAsFixed(0)} ر.ي'),
                _buildReceiptRow('مبيعات آجل / ديون:', '${summary.debtSales.toStringAsFixed(0)} ر.ي'),
                pw.Divider(thickness: 0.5),
                _buildReceiptRow('إجمالي مبيعات الوردية:', '${summary.totalSales.toStringAsFixed(0)} ر.ي', bold: true),
                _buildReceiptRow('عدد الفواتير المنفذة:', '${summary.salesCount} فاتورة'),
                _buildReceiptRow('مصاريف نقدية مخرجة:', '- ${summary.shiftExpenses.toStringAsFixed(0)} ر.ي'),
                _buildReceiptRow('مرتجعات نقدية:', '- ${summary.shiftReturns.toStringAsFixed(0)} ر.ي'),
                
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1),
                pw.Text('مطابقة الصندوق والعد الفعلي:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                _buildReceiptRow('النقد المتوقع بالدرج:', '${summary.expectedCashInDrawer.toStringAsFixed(0)} ر.ي', bold: true),
                _buildReceiptRow('العد الفعلي للكاشير:', '${summary.actualCashCount.toStringAsFixed(0)} ر.ي', bold: true),
                pw.Divider(thickness: 0.5),
                _buildReceiptRow(
                  isBalanced ? 'الحالة: مطابق تماماً' : (isShortage ? 'عجز في الدرج:' : 'زيادة في الدرج:'),
                  '${summary.cashVariance.abs().toStringAsFixed(0)} ر.ي',
                  bold: true,
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text('توقيع الكاشير: ________________', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text('PharmaOS Shift Management', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Shift_ZReport_${DateFormat("yyyyMMdd_HHmm").format(summary.shiftEnd)}',
      );
    } catch (e) {
      debugPrint('❌ خطأ أثناء طباعة Z-Report: $e');
    }
  }

  static pw.Widget _buildReceiptRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  /// حفظ تقفيل الوردية في قاعدة البيانات وسجل الإغلاقات
  static Future<void> saveShiftHandoverRecord(ShiftHandoverSummary summary, {String? reportPath}) async {
    final db = sl<AppDatabase>();
    await db.into(db.dayClosings).insert(
          DayClosingsCompanion.insert(
            date: summary.shiftEnd,
            periodStart: summary.shiftStart,
            totalSales: summary.totalSales,
            totalReturns: summary.shiftReturns,
            totalExpenses: summary.shiftExpenses,
            totalVendorPayments: 0,
            costOfGoodsSold: summary.totalSales * 0.8,
            netProfit: (summary.totalSales * 0.2) - summary.shiftExpenses,
            cashInDrawer: summary.actualCashCount,
            reportPdfPath: Value(reportPath),
          ),
        );
  }

  /// طباعة تقرير الأرباح والخسائر الشامل (P&L Report) بصيغة A4
  static Future<void> printPeriodFinancialReport(FinancialPeriodSummary summary) async {
    try {
      final settings = await sl<SettingsRepository>().load();
      final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: ttf),
          header: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          settings.pharmacyName.isNotEmpty ? settings.pharmacyName : 'PharmaOS',
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        ),
                        pw.Text('تقرير الأرباح والخسائر والتحليل المالي المتقدم', style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('من: ${DateFormat("yyyy-MM-dd").format(summary.startDate)}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('إلى: ${DateFormat("yyyy-MM-dd").format(summary.endDate)}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('تاريخ الطباعة: ${DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColors.blueGrey400),
                pw.SizedBox(height: 8),
              ],
            );
          },
          build: (pw.Context ctx) {
            return [
              pw.Text('1. الملخص المالي العام (P&L Breakdown):', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['المؤشر المالي', 'القيمة (ريال يمني)', 'النسبة / التفصيل'],
                data: [
                  ['إجمالي المبيعات (Revenue)', '${summary.totalSales.toStringAsFixed(0)} ر.ي', '${summary.salesCount} عملية بيع'],
                  ['تكلفة البضاعة المباعة (COGS - FEFO)', '${summary.costOfGoodsSold.toStringAsFixed(0)} ر.ي', 'تكلفة الشراء الفعلية'],
                  ['إجمالي الربح (Gross Profit)', '${summary.grossProfit.toStringAsFixed(0)} ر.ي', 'هامش إجمالي: ${summary.grossProfitMargin.toStringAsFixed(1)}%'],
                  ['المصاريف التشغيلية والسحبيات', '${summary.totalExpenses.toStringAsFixed(0)} ر.ي', '${summary.expensesCount} عملية صرف'],
                  ['المرتجعات المنفذة', '${summary.totalReturns.toStringAsFixed(0)} ر.ي', 'مردودات مبيعات'],
                  ['تسديدات الموردين', '${summary.totalVendorPayments.toStringAsFixed(0)} ر.ي', 'سندات دفع نقدية'],
                  ['صافي الربح الحقيقي (Net Profit)', '${summary.netProfit.toStringAsFixed(0)} ر.ي', 'هامش صافي: ${summary.netProfitMargin.toStringAsFixed(1)}%'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              ),

              pw.SizedBox(height: 16),
              pw.Text('2. تفصيل طرق تحصيل المبيعات:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 16,
                runSpacing: 6,
                children: summary.paymentMethodsBreakdown.entries.map((e) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('• ${e.key}: ${e.value.toStringAsFixed(0)} ر.ي', style: const pw.TextStyle(fontSize: 9)),
                  );
                }).toList(),
              ),

              pw.SizedBox(height: 20),
              pw.Text('3. الأصناف الـ 10 الأكثر ربحية في الفترة:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
              pw.SizedBox(height: 8),
              if (summary.topProfitableMedicines.isEmpty)
                pw.Text('لا توجد مبيعات أصناف مسجلة في هذه الفترة', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['#', 'اسم الدواء / الصنف', 'الكمية المباعة', 'المبيعات', 'التكلفة', 'الربح الصافي', 'الهامش'],
                  data: summary.topProfitableMedicines.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final m = entry.value;
                    return [
                      '$idx',
                      m.name,
                      '${m.quantitySold}',
                      '${m.revenue.toStringAsFixed(0)} ر.ي',
                      '${m.cost.toStringAsFixed(0)} ر.ي',
                      '${m.profit.toStringAsFixed(0)} ر.ي',
                      '${m.profitMargin.toStringAsFixed(1)}%',
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                ),

              pw.SizedBox(height: 24),
              pw.Divider(thickness: 0.5),
              pw.Center(
                child: pw.Text('تم إنشاء هذا التقرير تلقائياً بواسطة نظام إدارة الصيدليات الموحد PharmaOS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Financial_PL_Report_${DateFormat("yyyyMMdd").format(summary.startDate)}_${DateFormat("yyyyMMdd").format(summary.endDate)}',
      );
    } catch (e) {
      debugPrint('❌ خطأ أثناء طباعة تقرير الأرباح والخسائر: $e');
    }
  }

  /// تصدير تقرير الأرباح والخسائر إلى ملف إكسل Excel
  static Future<String?> exportPeriodFinancialExcel(FinancialPeriodSummary summary) async {
    try {
      final settings = await sl<SettingsRepository>().load();
      final targetDirectoryPath = settings.savePath.isNotEmpty ? settings.savePath : 'C:\\PharmaOS_Closings';
      final dir = Directory(targetDirectoryPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final excel = xls.Excel.createExcel();
      final pLSheet = excel['الأرباح والخسائر'];
      excel.delete('Sheet1');

      // ورقة 1: الملخص
      pLSheet.appendRow([xls.TextCellValue('تقرير الأرباح والخسائر الشامل - ${settings.pharmacyName}')]);
      pLSheet.appendRow([xls.TextCellValue('الفترة: من ${DateFormat("yyyy-MM-dd").format(summary.startDate)} إلى ${DateFormat("yyyy-MM-dd").format(summary.endDate)}')]);
      pLSheet.appendRow([xls.TextCellValue('')]);
      pLSheet.appendRow([xls.TextCellValue('المؤشر المالي'), xls.TextCellValue('القيمة (ريال يمني)'), xls.TextCellValue('ملاحظات')]);
      pLSheet.appendRow([xls.TextCellValue('إجمالي المبيعات'), xls.TextCellValue(summary.totalSales.toStringAsFixed(0)), xls.TextCellValue('${summary.salesCount} عملية بيع')]);
      pLSheet.appendRow([xls.TextCellValue('تكلفة البضاعة المباعة (COGS)'), xls.TextCellValue(summary.costOfGoodsSold.toStringAsFixed(0)), xls.TextCellValue('تكلفة الشراء')]);
      pLSheet.appendRow([xls.TextCellValue('إجمالي الربح (Gross Profit)'), xls.TextCellValue(summary.grossProfit.toStringAsFixed(0)), xls.TextCellValue('هامش: ${summary.grossProfitMargin.toStringAsFixed(1)}%')]);
      pLSheet.appendRow([xls.TextCellValue('المصاريف التشغيلية'), xls.TextCellValue(summary.totalExpenses.toStringAsFixed(0)), xls.TextCellValue('${summary.expensesCount} عملية')]);
      pLSheet.appendRow([xls.TextCellValue('المرتجعات'), xls.TextCellValue(summary.totalReturns.toStringAsFixed(0)), xls.TextCellValue('')]);
      pLSheet.appendRow([xls.TextCellValue('تسديدات الموردين'), xls.TextCellValue(summary.totalVendorPayments.toStringAsFixed(0)), xls.TextCellValue('')]);
      pLSheet.appendRow([xls.TextCellValue('صافي الربح الحقيقي'), xls.TextCellValue(summary.netProfit.toStringAsFixed(0)), xls.TextCellValue('هامش صافي: ${summary.netProfitMargin.toStringAsFixed(1)}%')]);

      // ورقة 2: الأصناف الأكثر ربحية
      final medSheet = excel['الأصناف الأكثر ربحية'];
      medSheet.appendRow([xls.TextCellValue('الرقم'), xls.TextCellValue('اسم الصنف'), xls.TextCellValue('الكمية المباعة'), xls.TextCellValue('إجمالي المبيعات'), xls.TextCellValue('إجمالي التكلفة'), xls.TextCellValue('الربح الصافي'), xls.TextCellValue('نسبة الهامش %')]);
      for (int i = 0; i < summary.topProfitableMedicines.length; i++) {
        final m = summary.topProfitableMedicines[i];
        medSheet.appendRow([
          xls.IntCellValue(i + 1),
          xls.TextCellValue(m.name),
          xls.IntCellValue(m.quantitySold),
          xls.TextCellValue(m.revenue.toStringAsFixed(0)),
          xls.TextCellValue(m.cost.toStringAsFixed(0)),
          xls.TextCellValue(m.profit.toStringAsFixed(0)),
          xls.TextCellValue('${m.profitMargin.toStringAsFixed(1)}%'),
        ]);
      }

      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File('${dir.path}\\Financial_PL_$dateStr.xlsx');
        await file.writeAsBytes(fileBytes);
        return file.path;
      }
      return null;
    } catch (e) {
      debugPrint('❌ خطأ أثناء تصدير إكسل الأرباح والخسائر: $e');
      return null;
    }
  }
}

