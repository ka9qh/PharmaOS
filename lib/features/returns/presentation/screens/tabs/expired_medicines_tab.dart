import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../providers/returns_provider.dart';

class ExpiredMedicinesTab extends ConsumerStatefulWidget {
  const ExpiredMedicinesTab({super.key});

  @override
  ConsumerState<ExpiredMedicinesTab> createState() => _ExpiredMedicinesTabState();
}

class _ExpiredMedicinesTabState extends ConsumerState<ExpiredMedicinesTab> {
  final List<Map<String, dynamic>> _expiredItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void _showReturnDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _VendorReturnDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_expiredItems.isEmpty) {
      return const Center(child: Text('لا توجد أدوية منتهية أو قاربت على الانتهاء', style: TextStyle(fontSize: 16)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _expiredItems.length,
      itemBuilder: (context, index) {
        final item = _expiredItems[index];
        final expiry = item['expiryDate'] as DateTime?;
        final isExpired = expiry != null && expiry.isBefore(DateTime.now());

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              Icons.warning_amber_rounded,
              color: isExpired ? Colors.red : Colors.orange,
              size: 32,
            ),
            title: Text(item['medicineName'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'المورد: ${item['supplierName']} | سعر الشراء: ${item['purchasePrice']}\n'
              'الكمية: ${item['quantity']} | الصلاحية: ${expiry != null ? DateFormat('yyyy/MM/dd').format(expiry) : 'غير محدد'}'
            ),
            isThreeLine: true,
            trailing: FilledButton(
              onPressed: () => _showReturnDialog(item),
              child: const Text('إرجاع للمورد'),
            ),
          ),
        );
      },
    );
  }
}

class _VendorReturnDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  const _VendorReturnDialog({required this.item});

  @override
  ConsumerState<_VendorReturnDialog> createState() => _VendorReturnDialogState();
}

class _VendorReturnDialogState extends ConsumerState<_VendorReturnDialog> {
  late final TextEditingController _qtyController;
  late final TextEditingController _amountController;
  final _reasonController = TextEditingController(text: 'مرتجع لتلف أو انتهاء صلاحية');
  String _settlementMethod = 'deduction';
  
  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: widget.item['quantity'].toString());
    _amountController = TextEditingController(
      text: ((widget.item['purchasePrice'] as num) * (widget.item['quantity'] as num)).toStringAsFixed(2)
    );
  }

  void _submit() async {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الطلب بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إرجاع ${widget.item['medicineName']} للمورد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _qtyController,
              decoration: const InputDecoration(labelText: 'الكمية المرتجعة'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'المبلغ المسترد الإجمالي (سعر الشراء × الكمية)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _settlementMethod,
              items: const [
                DropdownMenuItem(value: 'deduction', child: Text('خصم من مديونية المورد')),
                DropdownMenuItem(value: 'refund', child: Text('استرداد نقدي')),
                DropdownMenuItem(value: 'replacement', child: Text('استبدال')),
              ],
              onChanged: (v) => setState(() => _settlementMethod = v!),
              decoration: const InputDecoration(labelText: 'طريقة التسوية'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'سبب الإرجاع'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: const Text('تأكيد')),
      ],
    );
  }
}
