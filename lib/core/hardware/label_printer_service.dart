// طباعة ملصق باركود الدواء - PharmaOS
//
// قرار هندسي مهم (راجع docs/HARDWARE_INTEGRATION_GUIDE.md):
// بما أننا لا نعرف بعد الموديل الدقيق لطابعة الملصقات لديك، نستخدم حوار طباعة
// ويندوز القياسي (عبر حزمة printing) بدلاً من بروتوكول خام (TSPL/ZPL/ESC-POS).
// هذا يعمل مع أي طابعة مثبّت لها Driver عادي في ويندوز - أنت تختار الطابعة
// الصحيحة يدويًا من نافذة الطباعة التي ستظهر عند الضغط على "طباعة".
//
// إذا اختبرت هذا وكان الملصق يخرج بحجم أو جودة غير مناسبة، أخبرني بموديل
// الطابعة بالضبط، وسنبني Driver مخصص أسرع وأدق في core/hardware/printer_drivers/.

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LabelPrinterService {
  LabelPrinterService._();

  /// حجم الملصق الافتراضي: 50×30 مم (الأكثر شيوعًا لملصقات الأدوية في الصيدليات).
  /// TODO: اجعله قابلاً للتخصيص من شاشة الإعدادات إذا كانت ملصقاتك الفعلية بمقاس مختلف.
  static Future<void> printMedicineLabel({
    required String medicineName,
    required String barcodeValue,
    required double price,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          50 * PdfPageFormat.mm,
          30 * PdfPageFormat.mm,
          marginAll: 2 * PdfPageFormat.mm,
        ),
        build: (context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                medicineName,
                style: const pw.TextStyle(fontSize: 8),
                maxLines: 1,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: barcodeValue,
                width: 44 * PdfPageFormat.mm,
                height: 14 * PdfPageFormat.mm,
                drawText: true,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${price.toStringAsFixed(0)} ريال',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(bytes),
      name: 'PharmaOS_Label_$barcodeValue',
    );
  }
}
