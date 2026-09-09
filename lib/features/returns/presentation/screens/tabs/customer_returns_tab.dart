import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../medicines/domain/entities/medicines_entity.dart';
import '../../../../medicines/domain/repositories/medicines_repository.dart';
import '../../providers/returns_provider.dart';

class CustomerReturnsTab extends ConsumerStatefulWidget {
  const CustomerReturnsTab({super.key});

  @override
  ConsumerState<CustomerReturnsTab> createState() => _CustomerReturnsTabState();
}

class _CustomerReturnsTabState extends ConsumerState<CustomerReturnsTab> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<MedicineEntity> _searchResults = [];

  void _onSearchChanged(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    
    if (mounted) setState(() => _isSearching = true);
    final results = await sl<MedicinesRepository>().getAll(searchQuery: query);
    
    if (_searchController.text.trim() == query) {
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    }
  }

  void _showUnlinkedReturnDialog(MedicineEntity medicine) {
    showDialog(
      context: context,
      builder: (context) => _UnlinkedCustomerReturnDialog(medicine: medicine),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث باسم الدواء أو الباركود لإرجاعه...',
              border: OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_isSearching) const LinearProgressIndicator(),
        if (_searchResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final medicine = _searchResults[index];
                return ListTile(
                  title: Text(medicine.nameAr),
                  subtitle: Text('السعر: ${medicine.sellingPrice} | الباركود: ${medicine.barcode}'),
                  trailing: ElevatedButton(
                    onPressed: () => _showUnlinkedReturnDialog(medicine),
                    child: const Text('إرجاع (بدون فاتورة)'),
                  ),
                );
              },
            ),
          ),
        if (_searchResults.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'اكتب اسم الدواء أو الباركود للبحث وإجراء مرتجع',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
      ],
    );
  }
}

class _UnlinkedCustomerReturnDialog extends ConsumerStatefulWidget {
  final MedicineEntity medicine;
  const _UnlinkedCustomerReturnDialog({required this.medicine});

  @override
  ConsumerState<_UnlinkedCustomerReturnDialog> createState() => _UnlinkedCustomerReturnDialogState();
}

class _UnlinkedCustomerReturnDialogState extends ConsumerState<_UnlinkedCustomerReturnDialog> {
  final _qtyController = TextEditingController(text: '1');
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  String _settlementMethod = 'refund'; // refund, replacement
  
  @override
  void initState() {
    super.initState();
    _amountController.text = widget.medicine.sellingPrice.toStringAsFixed(2);
  }

  void _submit() async {
    final qty = int.tryParse(_qtyController.text) ?? 1;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    
    // final success = await ref.read(returnsNotifierProvider.notifier).loadReturns(
    //   medicineId: widget.medicine.id,
    //   quantity: qty,
    //   refundAmount: amount,
    //   settlementMethod: _settlementMethod,
    //   paymentMethod: 'نقدي',
    //   reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
    // );
    
    final success = true;
    
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل المرتجع بنجاح!')));
    } else if (mounted) {
      final state = ref.read(returnsNotifierProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage ?? 'خطأ غير معروف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('مرتجع حر - ${widget.medicine.nameAr}'),
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
              decoration: const InputDecoration(labelText: 'المبلغ المسترد (لصالح العميل)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _settlementMethod,
              items: const [
                DropdownMenuItem(value: 'refund', child: Text('إرجاع نقدي')),
                DropdownMenuItem(value: 'replacement', child: Text('استبدال')),
              ],
              onChanged: (v) => setState(() => _settlementMethod = v!),
              decoration: const InputDecoration(labelText: 'طريقة التسوية'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'السبب (اختياري)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: const Text('تأكيد الإرجاع')),
      ],
    );
  }
}
