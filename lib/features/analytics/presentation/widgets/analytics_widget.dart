import 'package:flutter/material.dart';
import '../../domain/entities/analytics_entity.dart';

class TopSellingTile extends StatelessWidget {
  final int rank;
  final TopSellingMedicine medicine;
  const TopSellingTile({super.key, required this.rank, required this.medicine});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text('$rank')),
      title: Text(medicine.medicineName),
      subtitle: Text('الكمية المباعة: ${medicine.totalQuantitySold}'),
      trailing: Text('${medicine.totalRevenue.toStringAsFixed(0)} ريال'),
    );
  }
}

class SalesTrendCard extends StatelessWidget {
  final SalesTrend trend;
  const SalesTrendCard({super.key, required this.trend});

  @override
  Widget build(BuildContext context) {
    final change = trend.percentChange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اتجاه المبيعات (آخر 7 أيام مقابل الأسبوع السابق)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  change == null ? Icons.remove : (trend.isUp ? Icons.trending_up : Icons.trending_down),
                  color: change == null ? Colors.grey : (trend.isUp ? Colors.green : Colors.red),
                ),
                const SizedBox(width: 8),
                Text(
                  change == null
                      ? 'لا توجد بيانات كافية للمقارنة'
                      : '${change.abs().toStringAsFixed(1)}% ${trend.isUp ? 'زيادة' : 'انخفاض'}',
                  style: TextStyle(
                      color: change == null ? Colors.grey : (trend.isUp ? Colors.green : Colors.red),
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('هذا الأسبوع: ${trend.currentPeriodTotal.toStringAsFixed(0)} ريال'),
            Text('الأسبوع السابق: ${trend.previousPeriodTotal.toStringAsFixed(0)} ريال'),
          ],
        ),
      ),
    );
  }
}
