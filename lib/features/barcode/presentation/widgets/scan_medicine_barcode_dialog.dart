import 'package:flutter/material.dart';
import '../../../../core/hardware/label_printer_service.dart';
import 'barcode_widget.dart';

class ScanMedicineBarcodeDialog extends StatefulWidget {
  final int medicineId;
  final String medicineName;
  final String currentBarcode;
  final double sellingPrice;
  final Future<bool> Function(String newBarcode) onBarcodeSaved;

  const ScanMedicineBarcodeDialog({
    super.key,
    required this.medicineId,
    required this.medicineName,
    required this.currentBarcode,
    required this.sellingPrice,
    required this.onBarcodeSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required int medicineId,
    required String medicineName,
    required String currentBarcode,
    required double sellingPrice,
    required Future<bool> Function(String newBarcode) onBarcodeSaved,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ScanMedicineBarcodeDialog(
        medicineId: medicineId,
        medicineName: medicineName,
        currentBarcode: currentBarcode,
        sellingPrice: sellingPrice,
        onBarcodeSaved: onBarcodeSaved,
      ),
    );
  }

  @override
  State<ScanMedicineBarcodeDialog> createState() => _ScanMedicineBarcodeDialogState();
}

class _ScanMedicineBarcodeDialogState extends State<ScanMedicineBarcodeDialog> {
  late final TextEditingController _barcodeController;
  final _focusNode = FocusNode();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.currentBarcode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _barcodeController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _barcodeController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final scanned = _barcodeController.text.trim();
    if (scanned.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال أو مسح الباركود أولاً');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onBarcodeSaved(scanned);
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade800,
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم ربط باركود الشركة للصنف "${widget.medicineName}" بنجاح: $scanned',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          setState(() => _errorMessage = 'حدث خطأ أثناء حفظ الباركود الجديد');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'خطأ: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.teal, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'قراءة / مسح باركود الصنف',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.medicineName,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // نص إرشادي
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'امسح الباركود المطبوع على علبة الدواء التابعة للشركة باستخدام القارئ اليدوي أو أدخله يدويًا للربط المباشر والاستغناء عن طباعة الملصقات.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // الباركود الحالي
              if (widget.currentBarcode.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('الباركود الحالي المسجل:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        widget.currentBarcode,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // حقل مسح/إدخال الباركود الجديد
              TextField(
                controller: _barcodeController,
                focusNode: _focusNode,
                autofocus: true,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                decoration: InputDecoration(
                  labelText: 'مسح أو كتابة الباركود الجديد (Enter للحفظ)',
                  hintText: 'مرر قارئ الباركود على العلبة الآن...',
                  prefixIcon: const Icon(Icons.barcode_reader, color: Colors.teal),
                  suffixIcon: _barcodeController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _barcodeController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _handleSave(),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ],

              const SizedBox(height: 16),

              // معاينة الباركود عند الإدخال
              if (_barcodeController.text.trim().isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: BarcodeLabelPreview(
                      barcodeValue: _barcodeController.text.trim(),
                      medicineName: widget.medicineName,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          // خيار ثانوي للطباعة إذا رغب المستخدم يوماً ما
          TextButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: const Text('طباعة ملصق (اختياري)', style: TextStyle(fontSize: 11)),
            onPressed: () async {
              final code = _barcodeController.text.trim().isNotEmpty
                  ? _barcodeController.text.trim()
                  : widget.currentBarcode;
              if (code.isNotEmpty) {
                await LabelPrinterService.printMedicineLabel(
                  medicineName: widget.medicineName,
                  barcodeValue: code,
                  price: widget.sellingPrice,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال ملصق الباركود للطباعة')),
                  );
                }
              }
            },
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: const Text('حفظ وتحديث باركود الشركة'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
    );
  }
}
