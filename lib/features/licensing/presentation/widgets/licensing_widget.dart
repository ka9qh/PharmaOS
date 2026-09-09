import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HardwareIdCard extends StatelessWidget {
  final String hardwareId;
  const HardwareIdCard({super.key, required this.hardwareId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('معرف هذا الجهاز', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'أرسل هذا المعرف لمزوّد النظام للحصول على مفتاح تفعيل خاص بجهازك',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    hardwareId,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'نسخ',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hardwareId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ معرف الجهاز')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
