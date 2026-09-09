// شاشة فواتير الموردين غير المسددة وسداد الدفعات - PharmaOS
// تدعم شريط بحث شامل، تصفية حسب المورد، وتوثيق السندات

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/vendor_payments_provider.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../../../invoices/presentation/screens/invoice_details_screen.dart';
import '../../../suppliers/presentation/providers/suppliers_provider.dart';

class VendorPaymentsScreen extends ConsumerStatefulWidget {
  final int? supplierId;
  const VendorPaymentsScreen({super.key, this.supplierId});

  @override
  ConsumerState<VendorPaymentsScreen> createState() => _VendorPaymentsScreenState();
}

class _VendorPaymentsScreenState extends ConsumerState<VendorPaymentsScreen> {
  int? _selectedSupplierId;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedSupplierId = widget.supplierId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vendorPaymentsNotifierProvider.notifier).loadUnpaidInvoices(supplierId: _selectedSupplierId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewPaymentDialog([InvoiceEntity? targetInvoice]) {
    final unpaidInvoices = ref.read(vendorPaymentsNotifierProvider).unpaidInvoices;
    if (unpaidInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد فواتير غير مسددة')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _NewPaymentDialog(
        invoices: unpaidInvoices,
        initialInvoice: targetInvoice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorPaymentsNotifierProvider);
    final suppliersState = ref.watch(suppliersNotifierProvider);
    final currencyFormat = NumberFormat.currency(symbol: 'ر.ي', decimalDigits: 0);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    final q = _searchQuery.trim().toLowerCase();
    final filteredInvoices = state.unpaidInvoices.where((inv) {
      final matchNum = inv.invoiceNumber.toLowerCase().contains(q);
      final matchParty = inv.partyName.toLowerCase().contains(q);
      final matchTotal = inv.totalAmount.toString().contains(q);
      final matchRem = inv.remainingAmount.toString().contains(q);
      return matchNum || matchParty || matchTotal || matchRem;
    }).toList();

    final totalUnpaidAmount = filteredInvoices.fold<double>(0.0, (sum, inv) => sum + inv.remainingAmount);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('فواتير الموردين غير المسددة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () => ref.read(vendorPaymentsNotifierProvider.notifier).loadUnpaidInvoices(supplierId: _selectedSupplierId),
            ),
          ],
        ),
        body: Column(
          children: [
            // بطاقة الإحصائيات وشريط البحث والفلترة
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('إجمالي المبالغ غير المسددة', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              const SizedBox(height: 4),
                              Text(
                                '${totalUnpaidAmount.toStringAsFixed(0)} ر.ي',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('عدد الفواتير المعلقة', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              const SizedBox(height: 4),
                              Text(
                                '${filteredInvoices.length} فاتورة',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // شريط البحث وتصفية المورد
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Colors.blue),
                            hintText: 'ابحث برقم الفاتورة، اسم المورد، أو المبلغ...',
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<int>(
                          decoration: InputDecoration(
                            labelText: 'تصفية بالمورد',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          value: _selectedSupplierId,
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('كافة الموردين'),
                            ),
                            ...suppliersState.items.map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedSupplierId = val);
                            ref.read(vendorPaymentsNotifierProvider.notifier).loadUnpaidInvoices(supplierId: val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // قائمة الفواتير
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.errorMessage != null
                      ? Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)))
                      : filteredInvoices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'لا توجد فواتير غير مسددة حالياً ✓\nكافة حسابات الموردين مسددة',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredInvoices.length,
                              itemBuilder: (context, index) {
                                final inv = filteredInvoices[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 1,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(14),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red.shade50,
                                      child: const Icon(Icons.receipt, color: Colors.red),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          'فاتورة: ${inv.invoiceNumber}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            inv.partyName,
                                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        children: [
                                          Text('الإجمالي: ${currencyFormat.format(inv.totalAmount)}'),
                                          const SizedBox(width: 12),
                                          Text(
                                            'المتبقي: ${currencyFormat.format(inv.remainingAmount)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            dateFormat.format(inv.date),
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FilledButton.icon(
                                          icon: const Icon(Icons.payment, size: 16),
                                          label: const Text('سداد'),
                                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                          onPressed: () => _showNewPaymentDialog(inv),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined),
                                          tooltip: 'عرض الفاتورة',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => InvoiceDetailsScreen(
                                                  invoiceId: inv.id,
                                                  invoice: inv,
                                                  invoiceNumber: inv.invoiceNumber,
                                                  invoiceType: inv.type,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showNewPaymentDialog(),
          icon: const Icon(Icons.add_card),
          label: const Text('سداد دفعة جديدة'),
        ),
      ),
    );
  }
}

class _NewPaymentDialog extends ConsumerStatefulWidget {
  final List<InvoiceEntity> invoices;
  final InvoiceEntity? initialInvoice;

  const _NewPaymentDialog({required this.invoices, this.initialInvoice});

  @override
  ConsumerState<_NewPaymentDialog> createState() => _NewPaymentDialogState();
}

class _NewPaymentDialogState extends ConsumerState<_NewPaymentDialog> {
  InvoiceEntity? _selectedInvoice;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'نقدي';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialInvoice != null) {
      _selectedInvoice = widget.initialInvoice;
      _amountController.text = _selectedInvoice!.remainingAmount.toStringAsFixed(0);
    } else if (widget.invoices.isNotEmpty) {
      _selectedInvoice = widget.invoices.first;
      _amountController.text = _selectedInvoice!.remainingAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.green),
            SizedBox(width: 8),
            Text('سداد دفعة للمورد'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<InvoiceEntity>(
                  decoration: const InputDecoration(
                    labelText: 'اختر الفاتورة المراد سدادها',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedInvoice,
                  items: widget.invoices.map((inv) {
                    return DropdownMenuItem(
                      value: inv,
                      child: Text('${inv.invoiceNumber} - ${inv.partyName} (المتبقي: ${inv.remainingAmount.toStringAsFixed(0)} ر.ي)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedInvoice = val;
                      if (val != null) {
                        _amountController.text = val.remainingAmount.toStringAsFixed(0);
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المسدد (ر.ي) *',
                    border: OutlineInputBorder(),
                    suffixText: 'ر.ي',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'طريقة السداد',
                    border: OutlineInputBorder(),
                  ),
                  value: _paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'نقدي', child: Text('نقدي (صندوق الصيدلية)')),
                    DropdownMenuItem(value: 'محفظة إلكترونية', child: Text('محفظة إلكترونية')),
                    DropdownMenuItem(value: 'تحويل بنكي', child: Text('تحويل بنكي / شيك')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentMethod = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات / رقم السند أو الحوالة',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _isSaving
                ? null
                : () async {
                    if (_selectedInvoice == null) return;
                    final amount = double.tryParse(_amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    setState(() => _isSaving = true);
                    final success = await ref.read(vendorPaymentsNotifierProvider.notifier).recordPayment(
                          purchaseId: _selectedInvoice!.id,
                          amount: amount,
                          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                        );

                    if (mounted) {
                      setState(() => _isSaving = false);
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تسجيل دفعة السداد بنجاح ✓'), backgroundColor: Colors.green),
                        );
                      }
                    }
                  },
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('تأكيد السداد'),
          ),
        ],
      ),
    );
  }
}
