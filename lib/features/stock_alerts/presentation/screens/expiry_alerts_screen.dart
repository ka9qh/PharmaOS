import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/expiry_alerts_provider.dart';

class ExpiryAlertsScreen extends ConsumerWidget {
  const ExpiryAlertsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expiryAlertsNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنبيهات انتهاء الصلاحية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(expiryAlertsNotifierProvider.notifier).loadAll();
            },
          )
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? const Center(
                  child: Text(
                    'لا يوجد أدوية قاربت على الانتهاء 🎉',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    child: ListView(
                      children: [
                        DataTable(
                          headingRowColor: MaterialStateProperty.all(theme.colorScheme.surfaceVariant),
                          columns: const [
                            DataColumn(label: Text('اسم الدواء', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('رقم التشغيلة (Batch)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('الكمية المتبقية', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('تاريخ الانتهاء', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: state.items.map((item) {
                            Color? rowColor;
                            String statusText = '';
                            
                            switch (item.expiryStatus) {
                              case 0:
                                rowColor = Colors.red.withOpacity(0.2);
                                statusText = 'منتهي الصلاحية!';
                                break;
                              case 1:
                                rowColor = Colors.orange.withOpacity(0.2);
                                statusText = 'أقل من 3 أشهر';
                                break;
                              case 2:
                                rowColor = Colors.yellow.withOpacity(0.2);
                                statusText = 'أقل من 6 أشهر';
                                break;
                            }

                            return DataRow(
                              color: MaterialStateProperty.all(rowColor),
                              cells: [
                                DataCell(Text(item.medicineName)),
                                DataCell(Text(item.batchNumber)),
                                DataCell(Text(item.quantity.toString())),
                                DataCell(Text(DateFormat('yyyy-MM-dd').format(item.expiryDate))),
                                DataCell(
                                  Row(
                                    children: [
                                      Icon(
                                        item.expiryStatus == 0 ? Icons.error : Icons.warning,
                                        color: item.expiryStatus == 0 ? Colors.red : (item.expiryStatus == 1 ? Colors.orange : Colors.orangeAccent),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: item.expiryStatus == 0 ? Colors.red.shade900 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
