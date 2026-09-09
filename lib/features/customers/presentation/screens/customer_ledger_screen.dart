import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/customer_ledger_provider.dart';
import '../../domain/entities/customers_entity.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final CustomerEntity customer;

  const CustomerLedgerScreen({Key? key, required this.customer}) : super(key: key);

  @override
  ConsumerState<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customerLedgerNotifierProvider.notifier).loadLedger(widget.customer.id);
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
      ref.read(customerLedgerNotifierProvider.notifier).loadLedger(
        widget.customer.id, 
        start: _startDate, 
        end: _endDate
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerLedgerNotifierProvider);
    final currency = NumberFormat.currency(symbol: 'ريال', decimalDigits: 0);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

    double finalBalance = state.entries.isNotEmpty ? state.entries.last.balance : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب العميل: ${widget.customer.name}'),
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
                ref.read(customerLedgerNotifierProvider.notifier).loadLedger(widget.customer.id);
              },
            ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'طباعة كشف الحساب',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم تفعيل الطباعة في التحديث القادم')),
              );
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الفترة: ${_startDate == null ? "الكل" : "${DateFormat('yyyy-MM-dd').format(_startDate!)} إلى ${DateFormat('yyyy-MM-dd').format(_endDate!)}"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'الرصيد النهائي: ${currency.format(finalBalance.abs())} ${finalBalance >= 0 ? "(عليه)" : "(له)"}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 18,
                          color: finalBalance >= 0 ? Colors.red.shade700 : Colors.green.shade700
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: state.entries.isEmpty
                      ? const Center(child: Text('لا توجد حركات مالية في هذه الفترة.'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
                              columns: const [
                                DataColumn(label: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('البيان', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('رقم المرجع', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('مدين (عليه)', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('دائن (له)', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('الرصيد', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: state.entries.map((entry) {
                                return DataRow(cells: [
                                  DataCell(Text(dateFormatter.format(entry.date))),
                                  DataCell(Text(entry.description)),
                                  DataCell(Text(entry.referenceNumber)),
                                  DataCell(Text(entry.debit > 0 ? currency.format(entry.debit) : '-')),
                                  DataCell(Text(entry.credit > 0 ? currency.format(entry.credit) : '-')),
                                  DataCell(
                                    Text(
                                      currency.format(entry.balance.abs()),
                                      style: TextStyle(
                                        color: entry.balance >= 0 ? Colors.red.shade700 : Colors.green.shade700,
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
    );
  }
}
