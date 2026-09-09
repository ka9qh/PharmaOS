// خدمة إعدادات الطابعات وقارئ الباركود والأجهزة الخارجية - PharmaOS
// تدعم الطابعات الحرارية (80mm و 58mm)، طابعات لاصقات الباركود، وقارئ الباركود

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di/service_locator.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';

class HardwareSettings {
  final String invoicePrinterName;
  final String barcodePrinterName;
  final int invoicePaperWidthMm; // 80 or 58
  final bool autoPrintReceipt;
  final bool openCashDrawer;
  final int labelWidthMm; // 50, 40, 38...
  final int labelHeightMm; // 30, 25, 28...
  final String labelContentStyle; // 'pure', 'name_price', 'full'
  final String barcodeEncoding; // 'code128', 'ean13', 'qr'
  final bool scannerAutoSubmit;
  final String receiptHeader;
  final String receiptFooter;

  const HardwareSettings({
    this.invoicePrinterName = '',
    this.barcodePrinterName = '',
    this.invoicePaperWidthMm = 80,
    this.autoPrintReceipt = false,
    this.openCashDrawer = false,
    this.labelWidthMm = 50,
    this.labelHeightMm = 30,
    this.labelContentStyle = 'name_price',
    this.barcodeEncoding = 'code128',
    this.scannerAutoSubmit = true,
    this.receiptHeader = 'أهلاً بكم في صيدليتنا',
    this.receiptFooter = 'نتمنى لكم دوام الصحة والعافية',
  });
}

class HardwareSettingsService {
  static const String _prefInvPrinter = 'hw_inv_printer_v1';
  static const String _prefBarPrinter = 'hw_bar_printer_v1';
  static const String _prefPaperWidth = 'hw_paper_width_v1';
  static const String _prefAutoPrint = 'hw_auto_print_v1';
  static const String _prefOpenDrawer = 'hw_open_drawer_v1';
  static const String _prefLabelWidth = 'hw_label_width_v1';
  static const String _prefLabelHeight = 'hw_label_height_v1';
  static const String _prefLabelStyle = 'hw_label_style_v1';
  static const String _prefBarEncoding = 'hw_bar_encoding_v1';
  static const String _prefScannerSubmit = 'hw_scanner_submit_v1';
  static const String _prefReceiptHeader = 'hw_receipt_header_v1';
  static const String _prefReceiptFooter = 'hw_receipt_footer_v1';

  static Future<HardwareSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return HardwareSettings(
      invoicePrinterName: prefs.getString(_prefInvPrinter) ?? '',
      barcodePrinterName: prefs.getString(_prefBarPrinter) ?? '',
      invoicePaperWidthMm: prefs.getInt(_prefPaperWidth) ?? 80,
      autoPrintReceipt: prefs.getBool(_prefAutoPrint) ?? false,
      openCashDrawer: prefs.getBool(_prefOpenDrawer) ?? false,
      labelWidthMm: prefs.getInt(_prefLabelWidth) ?? 50,
      labelHeightMm: prefs.getInt(_prefLabelHeight) ?? 30,
      labelContentStyle: prefs.getString(_prefLabelStyle) ?? 'name_price',
      barcodeEncoding: prefs.getString(_prefBarEncoding) ?? 'code128',
      scannerAutoSubmit: prefs.getBool(_prefScannerSubmit) ?? true,
      receiptHeader: prefs.getString(_prefReceiptHeader) ?? 'أهلاً بكم في صيدليتنا',
      receiptFooter: prefs.getString(_prefReceiptFooter) ?? 'نتمنى لكم دوام الصحة والعافية',
    );
  }

  static Future<void> saveSettings(HardwareSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefInvPrinter, s.invoicePrinterName);
    await prefs.setString(_prefBarPrinter, s.barcodePrinterName);
    await prefs.setInt(_prefPaperWidth, s.invoicePaperWidthMm);
    await prefs.setBool(_prefAutoPrint, s.autoPrintReceipt);
    await prefs.setBool(_prefOpenDrawer, s.openCashDrawer);
    await prefs.setInt(_prefLabelWidth, s.labelWidthMm);
    await prefs.setInt(_prefLabelHeight, s.labelHeightMm);
    await prefs.setString(_prefLabelStyle, s.labelContentStyle);
    await prefs.setString(_prefBarEncoding, s.barcodeEncoding);
    await prefs.setBool(_prefScannerSubmit, s.scannerAutoSubmit);
    await prefs.setString(_prefReceiptHeader, s.receiptHeader);
    await prefs.setString(_prefReceiptFooter, s.receiptFooter);
  }

  // طباعة ملصق باركود تجريبي حسب الإعدادات
  static Future<void> printTestBarcodeLabel({
    String medicineName = 'بانادول اكسترا 500 ملجم',
    String barcode = '6291100123456',
    double price = 1200,
    String expiry = '2028-12',
  }) async {
    final s = await loadSettings();
    final doc = pw.Document();

    String pharmacyName = 'صيدليتي';
    try {
      final pharmacySettings = await sl<SettingsRepository>().load();
      if (pharmacySettings.pharmacyName.isNotEmpty) pharmacyName = pharmacySettings.pharmacyName;
    } catch (_) {}

    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          s.labelWidthMm * PdfPageFormat.mm,
          s.labelHeightMm * PdfPageFormat.mm,
          marginAll: 1.5 * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) {
          if (s.labelContentStyle == 'pure') {
            return pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: barcode,
                width: (s.labelWidthMm - 6) * PdfPageFormat.mm,
                height: (s.labelHeightMm - 6) * PdfPageFormat.mm,
                drawText: true,
              ),
            );
          } else if (s.labelContentStyle == 'name_price') {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(medicineName, style: const pw.TextStyle(fontSize: 8), maxLines: 1),
                pw.SizedBox(height: 1),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: barcode,
                  width: (s.labelWidthMm - 6) * PdfPageFormat.mm,
                  height: (s.labelHeightMm * 0.45) * PdfPageFormat.mm,
                  drawText: true,
                ),
                pw.SizedBox(height: 1),
                pw.Text('السعر: ${price.toStringAsFixed(0)} ر.ي', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ],
            );
          } else {
            // Full details
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(pharmacyName, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.Text(medicineName, style: const pw.TextStyle(fontSize: 7.5), maxLines: 1),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: barcode,
                  width: (s.labelWidthMm - 6) * PdfPageFormat.mm,
                  height: (s.labelHeightMm * 0.38) * PdfPageFormat.mm,
                  drawText: true,
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('انتهاء: $expiry', style: const pw.TextStyle(fontSize: 6.5)),
                    pw.Text('${price.toStringAsFixed(0)} ر.ي', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            );
          }
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(bytes),
      name: 'Test_Barcode_Label',
    );
  }

  // طباعة فاتورة حرارية تجريبية
  static Future<void> printTestThermalReceipt() async {
    final s = await loadSettings();
    final doc = pw.Document();

    String pharmacyName = 'صيدلية الشفاء الحديثة';
    String phone = '777000000';
    try {
      final pharmacySettings = await sl<SettingsRepository>().load();
      if (pharmacySettings.pharmacyName.isNotEmpty) pharmacyName = pharmacySettings.pharmacyName;
      if (pharmacySettings.pharmacyPhone.isNotEmpty) phone = pharmacySettings.pharmacyPhone;
    } catch (_) {}

    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final widthMm = s.invoicePaperWidthMm;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          widthMm * PdfPageFormat.mm,
          double.infinity,
          marginAll: 3 * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(pharmacyName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('هاتف: $phone', style: const pw.TextStyle(fontSize: 9)),
              if (s.receiptHeader.isNotEmpty) pw.Text(s.receiptHeader, style: const pw.TextStyle(fontSize: 8)),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('فاتورة رقم: #TEST-101', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(DateTime.now().toIso8601String().split('T').first, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('الصنف', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Text('الكمية', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 8),
                  pw.Text('الإجمالي', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('أوجمنتين 1 جم', style: const pw.TextStyle(fontSize: 8))),
                  pw.Text('1', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(width: 8),
                  pw.Text('3,500 ر.ي', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('بنادول اكسترا', style: const pw.TextStyle(fontSize: 8))),
                  pw.Text('2', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(width: 8),
                  pw.Text('2,400 ر.ي', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الإجمالي النهائي:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('5,900 ر.ي', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 8),
              if (s.receiptFooter.isNotEmpty)
                pw.Text(s.receiptFooter, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 6),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: 'TEST-101',
                width: (widthMm * 0.6) * PdfPageFormat.mm,
                height: 12 * PdfPageFormat.mm,
                drawText: false,
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(bytes),
      name: 'Test_Thermal_Receipt',
    );
  }
}
