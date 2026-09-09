import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import '../../features/invoices/domain/entities/invoice_entity.dart';

class InvoicePrinterService {
  static Future<void> printInvoice(InvoiceEntity invoice) async {
    final pdf = pw.Document();

    // تحميل خط يدعم اللغة العربية
    // يمكننا استخدام خط مدمج من printing أو تحميل خط من assets
    // هنا سنستخدم Arabic font من google fonts
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final currencyFormat = NumberFormat.currency(symbol: 'ر.ي', decimalDigits: 0);
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');
    final isSale = invoice.type == 'SALE';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isSale ? 'فاتورة مبيعات' : 'فاتورة مشتريات',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('رقم الفاتورة: ${invoice.invoiceNumber}'),
                      pw.Text('التاريخ: ${dateFormat.format(invoice.date)}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('نظام PharmaOS للصيدليات', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text(isSale ? 'العميل: ${invoice.partyName}' : 'المورد: ${invoice.partyName}'),
                      pw.Text('طريقة الدفع: ${invoice.paymentMethod}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Name
                  1: const pw.FlexColumnWidth(1), // Qty
                  2: const pw.FlexColumnWidth(1.5), // Price
                  3: const pw.FlexColumnWidth(1.5), // Total
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('الصنف', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('الكمية', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('السعر', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('المجموع', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Table Rows
                  ...invoice.items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(item.medicineName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(currencyFormat.format(item.unitPrice), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(currencyFormat.format(item.subtotal), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('الإجمالي العام:'),
                            pw.Text(currencyFormat.format(invoice.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        if (invoice.discount > 0)
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('الخصم:'),
                              pw.Text(currencyFormat.format(invoice.discount)),
                            ],
                          ),
                        if (!isSale && invoice.paidAmount != null) ...[
                          pw.Divider(),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('المدفوع:'),
                              pw.Text(currencyFormat.format(invoice.paidAmount!)),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('المتبقي آجل:'),
                              pw.Text(currencyFormat.format(invoice.remainingAmount)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text('شكراً لتعاملكم معنا!', style: const pw.TextStyle(color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${isSale ? "Sale" : "Purchase"}_Invoice_${invoice.invoiceNumber}',
    );
  }
}
