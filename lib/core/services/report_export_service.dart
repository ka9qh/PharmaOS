// تصدير تقرير إغلاق النوبة إلى PDF وExcel - يُحفظ محليًا في مجلد reports
// داخل مجلد بيانات التطبيق (Application Support Directory).
//
// تصحيح Phase 9: كان هذا الملف يستخدم summary.date وهو حقل لم يعد موجودًا
// بعد تصحيح إزالة قفل اليومية (أصبح periodStart/periodEnd) - تم اكتشافه
// وإصلاحه أثناء إضافة دمج الإعدادات (اسم الصيدلية والعملة).

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xls;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'day_closing_service.dart' show DayClosingSummary;
import '../../features/settings/domain/repositories/settings_repository.dart';

class ReportExportService {
  final SettingsRepository _settingsRepository;
  ReportExportService(this._settingsRepository);

  Future<Directory> _reportsDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'reports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _dateStamp(DateTime date) => '${date.year}-${_two(date.month)}-${_two(date.day)}';
  String _timeStamp(DateTime date) => '${_two(date.hour)}-${_two(date.minute)}';
  String _two(int value) => value.toString().padLeft(2, '0');

  String _fullDateTime(DateTime date) =>
      '${_dateStamp(date)} ${_two(date.hour)}:${_two(date.minute)}';

  Future<String> generatePdf(DayClosingSummary summary) async {
    final dir = await _reportsDir();
    final settings = await _settingsRepository.load();
    final file = File(p.join(
      dir.path,
      'report_${_dateStamp(summary.periodEnd)}_${_timeStamp(summary.periodEnd)}.pdf',
    ));

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  settings.pharmacyName.isEmpty ? 'PharmaOS' : settings.pharmacyName,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('تقرير إغلاق نوبة'),
                pw.SizedBox(height: 8),
                pw.Text('الفترة: من ${_fullDateTime(summary.periodStart)} إلى ${_fullDateTime(summary.periodEnd)}'),
                pw.SizedBox(height: 16),
                _row('إجمالي المبيعات', summary.totalSales, settings.currencyLabel),
                _row('إجمالي المرتجعات', summary.totalReturns, settings.currencyLabel),
                _row('تكلفة البضاعة المباعة', summary.costOfGoodsSold, settings.currencyLabel),
                _row('إجمالي المصاريف', summary.totalExpenses, settings.currencyLabel),
                _row('إجمالي التسديدات للموردين', summary.totalVendorPayments, settings.currencyLabel),
                pw.Divider(),
                _row('صافي الربح', summary.netProfit, settings.currencyLabel, bold: true),
                _row('النقدية المتوقعة في الصندوق', summary.cashInDrawer, settings.currencyLabel, bold: true),
                pw.SizedBox(height: 20),
                pw.Text('أدوية تحتاج إعادة طلب (${summary.lowStockItems.length})',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                if (summary.lowStockItems.isEmpty) pw.Text('لا توجد أدوية ناقصة حاليًا.'),
                ...summary.lowStockItems.map(
                  (s) => pw.Text('- ${s.medicineName}: متبقي ${s.totalQuantity} (حد التنبيه ${s.reorderLevel})'),
                ),
              ],
            ),
          );
        },
      ),
    );

    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  pw.Widget _row(String label, double value, String currency, {bool bold = false}) {
    final style = bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13) : null;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text('${value.toStringAsFixed(0)} $currency', style: style),
        ],
      ),
    );
  }

  Future<String> generateExcel(DayClosingSummary summary) async {
    final dir = await _reportsDir();
    final settings = await _settingsRepository.load();
    final file = File(p.join(
      dir.path,
      'report_${_dateStamp(summary.periodEnd)}_${_timeStamp(summary.periodEnd)}.xlsx',
    ));

    final excelFile = xls.Excel.createExcel();
    final sheet = excelFile['إغلاق النوبة'];
    excelFile.delete('Sheet1');

    sheet.appendRow([xls.TextCellValue('الصيدلية'), xls.TextCellValue(settings.pharmacyName)]);
    sheet.appendRow([xls.TextCellValue('البند'), xls.TextCellValue('القيمة')]);
    sheet.appendRow([xls.TextCellValue('بداية الفترة'), xls.TextCellValue(_fullDateTime(summary.periodStart))]);
    sheet.appendRow([xls.TextCellValue('نهاية الفترة'), xls.TextCellValue(_fullDateTime(summary.periodEnd))]);
    sheet.appendRow([xls.TextCellValue('إجمالي المبيعات'), xls.DoubleCellValue(summary.totalSales)]);
    sheet.appendRow([xls.TextCellValue('إجمالي المرتجعات'), xls.DoubleCellValue(summary.totalReturns)]);
    sheet.appendRow(
        [xls.TextCellValue('تكلفة البضاعة المباعة'), xls.DoubleCellValue(summary.costOfGoodsSold)]);
    sheet.appendRow([xls.TextCellValue('إجمالي المصاريف'), xls.DoubleCellValue(summary.totalExpenses)]);
    sheet.appendRow([
      xls.TextCellValue('إجمالي التسديدات للموردين'),
      xls.DoubleCellValue(summary.totalVendorPayments)
    ]);
    sheet.appendRow([xls.TextCellValue('صافي الربح'), xls.DoubleCellValue(summary.netProfit)]);
    sheet.appendRow(
        [xls.TextCellValue('النقدية المتوقعة'), xls.DoubleCellValue(summary.cashInDrawer)]);
    sheet.appendRow([xls.TextCellValue('العملة'), xls.TextCellValue(settings.currencyLabel)]);
    sheet.appendRow([]);
    sheet.appendRow([xls.TextCellValue('أدوية تحتاج إعادة طلب')]);
    sheet.appendRow([xls.TextCellValue('الدواء'), xls.TextCellValue('الكمية المتبقية'), xls.TextCellValue('حد التنبيه')]);
    for (final item in summary.lowStockItems) {
      sheet.appendRow([
        xls.TextCellValue(item.medicineName),
        xls.IntCellValue(item.totalQuantity),
        xls.IntCellValue(item.reorderLevel),
      ]);
    }

    final bytes = excelFile.save();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }
    return file.path;
  }
}
