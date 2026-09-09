import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/supplier_ledger_provider.dart';
import '../../domain/entities/suppliers_entity.dart';

class SupplierLedgerScreen extends ConsumerStatefulWidget {
  final SupplierEntity supplier;

  const SupplierLedgerScreen({Key? key, required this.supplier}) : super(key: key);

  @override
  ConsumerState<SupplierLedgerScreen> createState() => _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState extends ConsumerState<SupplierLedgerScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(supplierLedgerNotifierProvider.notifier).loadLedger(widget.supplier.id);
    });
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null 
          ? DateTimeRange(start: _startDate!, end: _endDate!) 
          : null,
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      ref.read(supplierLedgerNotifierProvider.notifier).loadLedger(
        widget.supplier.id, 
        start: _startDate, 
        end: _endDate
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierLedgerNotifierProvider);
    final currency = NumberFormat.currency(symbol: 'ريال', decimalDigits: 0);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

    final totalCredit = state.entries.fold<double>(0, (sum, e) => sum + e.credit);
    final totalDebit = state.entries.fold<double>(0, (sum, e) => sum + e.debit);
    final finalBalance = totalCredit - totalDebit;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('كشف حساب ومطابقة المورد: ${widget.supplier.name}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.date_range),
              tooltip: 'تحديد فترة',
              onPressed: _selectDateRange,
            ),
            if (_startDate != null || _endDate != null)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'إلغاء الفلترة',
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  ref.read(supplierLedgerNotifierProvider.notifier).loadLedger(widget.supplier.id);
                },
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () => ref.read(supplierLedgerNotifierProvider.notifier).loadLedger(widget.supplier.id),
            ),
          ],
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, color: Colors.red),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                            onPressed: () => ref
                                .read(supplierLedgerNotifierProvider.notifier)
                                .loadLedger(widget.supplier.id),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                children: [
                  // بطاقات ملخص الحساب
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Colors.blueGrey.shade50,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('إجمالي المشتريات (له)', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                const SizedBox(height: 4),
                                Text(currency.format(totalCredit), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('إجمالي المسدد (عليه)', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                const SizedBox(height: 4),
                                Text(currency.format(totalDebit), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: finalBalance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: finalBalance > 0 ? Colors.red.shade300 : Colors.green.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  finalBalance > 0 ? 'المتبقي للمورد (دين)' : (finalBalance < 0 ? 'رصيد لصالحنا' : 'الحساب خالص'),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: finalBalance > 0 ? Colors.red.shade900 : Colors.green.shade900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currency.format(finalBalance.abs()),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: finalBalance > 0 ? Colors.red.shade800 : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: state.entries.isEmpty
                        ? const Center(child: Text('لا توجد حركات مالية مسجلة لهذا المورد في هذه الفترة.'))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
                                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                columns: const [
                                  DataColumn(label: Text('التاريخ')),
                                  DataColumn(label: Text('البيان والعملية')),
                                  DataColumn(label: Text('رقم المرجع')),
                                  DataColumn(label: Text('مدين / مسدد (عليه)')),
                                  DataColumn(label: Text('دائن / مشتريات (له)')),
                                  DataColumn(label: Text('الرصيد التراكمي')),
                                ],
                                rows: state.entries.map((entry) {
                                  return DataRow(cells: [
                                    DataCell(Text(dateFormatter.format(entry.date))),
                                    DataCell(Text(entry.description, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(entry.referenceNumber, style: const TextStyle(color: Colors.blueGrey))),
                                    DataCell(Text(entry.debit > 0 ? currency.format(entry.debit) : '-', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                    DataCell(Text(entry.credit > 0 ? currency.format(entry.credit) : '-', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                                    DataCell(
                                      Text(
                                        '${currency.format(entry.balance.abs())} ${entry.balance > 0 ? "(له)" : (entry.balance < 0 ? "(لنا)" : "")}',
                                        style: TextStyle(
                                          color: entry.balance > 0 ? Colors.red.shade700 : (entry.balance < 0 ? Colors.green.shade700 : Colors.black87),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
