import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../core/services/gemini_online_ai_service.dart';

class AiInvoiceScannerScreen extends StatefulWidget {
  const AiInvoiceScannerScreen({super.key});

  @override
  State<AiInvoiceScannerScreen> createState() => _AiInvoiceScannerScreenState();
}

class _AiInvoiceScannerScreenState extends State<AiInvoiceScannerScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  String _statusMessage = 'اختر صورة الفاتورة للمتابعة';

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _statusMessage = 'جاري تحليل الفاتورة بواسطة الذكاء الاصطناعي...';
          _isProcessing = true;
        });
        _processInvoice(_imageFile!);
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء التقاط الصورة: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _processInvoice(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final systemInstruction = '''
أنت نظام خبير في استخراج البيانات من فواتير الشراء الصيدلانية.
قم بتحليل الصورة المرفقة واستخراج البيانات التالية بصيغة JSON فقط، بدون أي نصوص إضافية.
يجب أن يحتوي الـ JSON على المفاتيح التالية:
{
  "supplierName": "اسم المورد أو الشركة",
  "invoiceNumber": "رقم الفاتورة (إن وجد)",
  "totalAmount": 1500.0,
  "items": [
    {
      "name": "اسم الدواء",
      "qtyCarton": 0,
      "qtyPack": 0,
      "qtyStrip": 0,
      "qtyPill": 0,
      "totalPills": 30, 
      "unitCost": 50.0
    }
  ]
}
ملاحظة: totalPills تعني الكمية الكلية بالوحدة الصغرى (حبة)، بينما qtyCarton, qtyPack... تعني التفصيل حسب ما هو مكتوب بالفاتورة.
إذا لم تجد بعض البيانات، ضعها كقيمة فارغة أو 0.
''';

      final prompt = 'استخرج بيانات الفاتورة المرفقة.';
      
      final result = await GeminiOnlineAiService.askAi(
        prompt: prompt,
        imageBase64: base64Image,
        customSystemInstruction: systemInstruction,
        jsonMode: true,
      );

      // تنظيف النص في حال أعاد الذكاء الاصطناعي markdown ```json ... ```
      String cleanJson = result.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }

      final parsedData = jsonDecode(cleanJson.trim());
      
      // حفظ الصورة محلياً في مجلد دائم إذا لم تكن فيه
      final directory = await getApplicationDocumentsDirectory();
      final invoicesDir = Directory(p.join(directory.path, 'PharmaOS', 'Invoices'));
      if (!await invoicesDir.exists()) {
        await invoicesDir.create(recursive: true);
      }
      final newImagePath = p.join(invoicesDir.path, 'INV_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final savedImage = await file.copy(newImagePath);
      
      parsedData['savedImagePath'] = savedImage.path;

      if (mounted) {
        Navigator.of(context).pop(parsedData);
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'فشل في تحليل الفاتورة. تأكد من جودة الصورة واتصال الإنترنت.\n$e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المسح الذكي للفواتير (Gemini AI)')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_imageFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_imageFile!, height: 300, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 24),
                ],
                if (_isProcessing)
                  const CircularProgressIndicator()
                else
                  const Icon(Icons.document_scanner, size: 80, color: Colors.blueGrey),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                if (!_isProcessing) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('الكاميرا'),
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('المعرض'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      ),
                    ],
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
