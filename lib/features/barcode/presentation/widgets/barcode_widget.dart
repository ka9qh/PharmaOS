// معاينة الباركود مباشرة داخل التطبيق (قبل الطباعة الفعلية)
// يُستخدم داخل شاشات ميزة medicines عند إضافة/عرض دواء.

import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';

class BarcodeLabelPreview extends StatelessWidget {
  final String barcodeValue;
  final String medicineName;

  const BarcodeLabelPreview({
    super.key,
    required this.barcodeValue,
    required this.medicineName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medicineName, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          BarcodeWidget(
            barcode: Barcode.code128(),
            data: barcodeValue,
            width: 200,
            height: 80,
            drawText: true,
          ),
        ],
      ),
    );
  }
}
