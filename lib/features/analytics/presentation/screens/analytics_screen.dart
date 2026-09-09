// شاشة التحليلات - قواعد حسابية بحتة (Rule-Based) وليست ذكاءً توليديًا
// راجع docs/AI_DEVELOPMENT_GUIDE.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../widgets/analytics_widget.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('التحليلات')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.salesTrend != null) SalesTrendCard(trend: state.salesTrend!),
                  const SizedBox(height: 16),
                  Text('الأكثر مبيعًا (آخر 30 يومًا)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (state.topSelling.isEmpty)
                    const Text('لا توجد بيانات مبيعات كافية بعد')
                  else
                    ...state.topSelling.asMap().entries.map(
                          (e) => TopSellingTile(rank: e.key + 1, medicine: e.value),
                        ),
                  const SizedBox(height: 16),
                  Text('أدوية قاربت على الانتهاء (خلال 30 يومًا)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (state.expiringSoon.isEmpty)
                    const Text('لا توجد أدوية قاربت على الانتهاء')
                  else
                    ...state.expiringSoon.map((b) => ListTile(
                          leading: Icon(
                            b.isAlreadyExpired ? Icons.error_outline : Icons.access_time,
                            color: b.isAlreadyExpired ? Colors.red : Colors.orange,
                          ),
                          title: Text(b.medicineName),
                          subtitle: Text(
                            b.isAlreadyExpired
                                ? 'منتهي الصلاحية بالفعل (الكمية: ${b.quantity})'
                                : 'ينتهي خلال ${b.daysUntilExpiry} يومًا (الكمية: ${b.quantity})',
                          ),
                        )),
                ],
              ),
      ),
    );
  }
}
