import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../returns/domain/repositories/returns_repository.dart';
import '../../../returns/domain/entities/returns_entity.dart';
import 'package:intl/intl.dart' hide TextDirection;

class POSReturnsDialog extends ConsumerStatefulWidget {
  const POSReturnsDialog({super.key});

  @override
  ConsumerState<POSReturnsDialog> createState() => _POSReturnsDialogState();
}

class _POSReturnsDialogState extends ConsumerState<POSReturnsDialog> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<SaleLookupResult> _searchResults = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecentSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSales() async {
    setState(() => _isLoading = true);
    try {
      final repo = sl<ReturnsRepository>();
      final results = await repo.getRecentSalesForReturns(limit: 20);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _loadRecentSales();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = sl<ReturnsRepository>();
      List<SaleLookupResult> results = [];
      
      // Try by invoice number first
      final byInvoice = await repo.findSaleByInvoiceNumber(q);
      if (byInvoice != null) {
        results.add(byInvoice);
      }
      
      // If no exact invoice, search by medicine name
      if (results.isEmpty) {
        results = await repo.findSalesByMedicineName(q);
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
          _searchQuery = q;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _showInvoiceDetails(SaleLookupResult sale) {
    showDialog(
      context: context,
      builder: (context) => _BulkReturnProcessDialog(sale: sale),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.keyboard_return, color: Colors.orange, size: 28),
                      SizedBox(width: 12),
                      Text('مرتجعات المبيعات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'ابحث برقم الفاتورة أو اسم العلاج',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onSubmitted: _performSearch,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty ? 'لا توجد مبيعات قريبة' : 'لم يتم العثور على نتائج للبحث "$_searchQuery"',
                                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final sale = _searchResults[index];
                              
                              // Check if fully returned
                              bool isFullyReturned = true;
                              int totalItems = 0;
                              int totalReturned = 0;
                              for(var item in sale.items) {
                                totalItems += item.originalQuantity;
                                totalReturned += item.alreadyReturned;
                                if(item.alreadyReturned < item.originalQuantity) {
                                  isFullyReturned = false;
                                }
                              }

                              return ListTile(
                                tileColor: isFullyReturned ? Colors.grey.shade100 : Colors.white,
                                title: Text(
                                  'فاتورة رقم: ${sale.invoiceNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isFullyReturned ? TextDecoration.lineThrough : null,
                                    color: isFullyReturned ? Colors.grey : Colors.black,
                                  ),
                                ),
                                subtitle: Text('عدد الأصناف: ${sale.items.length} | المرتجع: $totalReturned من $totalItems'),
                                trailing: ElevatedButton(
                                  onPressed: isFullyReturned ? null : () => _showInvoiceDetails(sale),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFullyReturned ? Colors.grey : Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('التفاصيل والمرتجع'),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkReturnProcessDialog extends StatefulWidget {
  final SaleLookupResult sale;
  const _BulkReturnProcessDialog({required this.sale});

  @override
  State<_BulkReturnProcessDialog> createState() => _BulkReturnProcessDialogState();
}

class _BulkReturnProcessDialogState extends State<_BulkReturnProcessDialog> {
  final Map<int, int> _returnQuantities = {};
  bool _isProcessing = false;

  double get _totalRefundAmount {
    double total = 0;
    for (final item in widget.sale.items) {
      final qty = _returnQuantities[item.saleItemId] ?? 0;
      total += qty * item.unitPrice;
    }
    return total;
  }

  void _submitReturn() async {
    if (_returnQuantities.values.every((q) => q == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تحديد كمية مرتجعة واحدة على الأقل')));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final repo = sl<ReturnsRepository>();
      await repo.processBulkCustomerReturn(
        saleId: widget.sale.saleId,
        returnQuantities: _returnQuantities,
        totalRefundAmount: _totalRefundAmount,
        settlementMethod: 'نقدي',
        paymentMethod: 'نقدي',
        reason: 'مرتجع عميل مباشر من نقطة البيع',
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context); // Close bulk return dialog
        Navigator.pop(context); // Close main returns dialog to refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرجاع الأصناف وقطع الفاتورة العكسية بنجاح!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تفاصيل الفاتورة: ${widget.sale.invoiceNumber}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.sale.items.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = widget.sale.items[index];
                    final maxReturnable = item.originalQuantity - item.alreadyReturned;
                    final isFullyReturned = maxReturnable <= 0;
                    final currentReturnQty = _returnQuantities[item.saleItemId] ?? 0;

                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.medicineName, style: TextStyle(fontWeight: FontWeight.bold, decoration: isFullyReturned ? TextDecoration.lineThrough : null)),
                              Text('السعر: ${item.unitPrice} | الكمية: ${item.originalQuantity} | مرتجع سابق: ${item.alreadyReturned}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: isFullyReturned
                              ? const Text('مرتجع بالكامل', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text('المرتجع: '),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: currentReturnQty > 0
                                          ? () => setState(() => _returnQuantities[item.saleItemId] = currentReturnQty - 1)
                                          : null,
                                    ),
                                    Text('$currentReturnQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: currentReturnQty < maxReturnable
                                          ? () => setState(() => _returnQuantities[item.saleItemId] = currentReturnQty + 1)
                                          : null,
                                    ),
                                    Text(' / $maxReturnable', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(thickness: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي المبلغ المسترد:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${_totalRefundAmount.toStringAsFixed(2)} ريال', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.assignment_return),
                    label: const Text('تأكيد الإرجاع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _isProcessing ? null : _submitReturn,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
