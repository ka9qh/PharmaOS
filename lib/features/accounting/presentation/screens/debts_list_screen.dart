// شاشة قائمة ديون الصيدلية - الخطوة 12
// تعرض ملخص لكل مورد/شركة: إجمالي الدين، المدفوع، المتبقي
// الضغط على أي مورد ينتقل مباشرة لشاشة التسديدات مع تعبئة بيانات المورد تلقائياً

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../accounting/presentation/providers/accounting_provider.dart';
import '../../../accounting/presentation/screens/accounting_screen.dart';
import '../../../accounting/domain/entities/accounting_entity.dart';

class DebtsListScreen extends ConsumerWidget {
  const DebtsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountingNotifierProvider);
    final currencyFormat = NumberFormat.currency(symbol: 'ر.ي', decimalDigits: 0);

    final allBalances = state.balances;
    final debtors = allBalances.where((b) => b.remainingDebt > 0).toList()
      ..sort((a, b) => b.remainingDebt.compareTo(a.remainingDebt)); // الأعلى ديناً أولاً
    final settledSuppliers = allBalances.where((b) => b.remainingDebt <= 0).toList();

    final totalDebt = debtors.fold<double>(0, (sum, b) => sum + b.remainingDebt);
    final totalPaid = allBalances.fold<double>(0, (sum, b) => sum + b.totalPaid);
    final totalPurchased = allBalances.fold<double>(0, (sum, b) => sum + b.totalPurchased);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قائمة ديون الصيدلية'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(accountingNotifierProvider.notifier).loadAll(),
            ),
          ],
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // بطاقة الملخص العام
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade700, Colors.orange.shade600],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('ملخص ديون الصيدلية', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _summaryCard('إجمالي المشتريات', currencyFormat.format(totalPurchased), Colors.white),
                            _summaryCard('المدفوع', currencyFormat.format(totalPaid), Colors.greenAccent),
                            _summaryCard('المتبقي', currencyFormat.format(totalDebt), Colors.yellowAccent),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (totalPurchased > 0)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalPaid / totalPurchased,
                              minHeight: 10,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // قائمة الموردين الذين عليهم ديون
                  if (debtors.isEmpty)
                    const Expanded(
                      child: Center(child: Text('لا توجد ديون مستحقة 🎉', style: TextStyle(fontSize: 20))),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: debtors.length + (settledSuppliers.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < debtors.length) {
                            return _buildDebtCard(context, debtors[index], currencyFormat);
                          }
                          // عنوان الموردين المسددين
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                Text(
                                  'موردون تم تسديدهم بالكامل (${settledSuppliers.length})',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                ),
                                ...settledSuppliers.map((b) => ListTile(
                                      leading: const Icon(Icons.check_circle, color: Colors.green),
                                      title: Text(b.supplierName),
                                      subtitle: Text('إجمالي: ${currencyFormat.format(b.totalPurchased)}'),
                                    )),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDebtCard(BuildContext context, SupplierBalance b, NumberFormat currencyFormat) {
    final paidPercent = b.totalPurchased > 0 ? (b.totalPaid / b.totalPurchased * 100).clamp(0.0, 100.0) : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          // الانتقال مباشرة لشاشة التسديدات مع تعبئة بيانات المورد
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountingScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(b.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Text(
                    currencyFormat.format(b.remainingDebt),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('إجمالي: ${currencyFormat.format(b.totalPurchased)}', style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    child: Text('مدفوع: ${currencyFormat.format(b.totalPaid)}',
                        style: TextStyle(fontSize: 13, color: Colors.green.shade700)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: paidPercent / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    paidPercent > 75 ? Colors.green : (paidPercent > 40 ? Colors.orange : Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${paidPercent.toStringAsFixed(0)}% مسدد', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Text('اضغط للتسديد ←', style: TextStyle(fontSize: 12, color: Colors.blue)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
