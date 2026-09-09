import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/stock_alerts_provider.dart';
import '../widgets/stock_alerts_widget.dart';

class StockAlertsScreen extends ConsumerWidget {
  const StockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockAlertsNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تنبيهات نقص المخزون')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty
                ? const Center(child: Text('لا توجد أدوية تحت حد التنبيه حاليًا ✓'))
                : ListView.builder(
                    itemCount: state.items.length,
                    itemBuilder: (context, index) => LowStockTile(item: state.items[index]),
                  ),
      ),
    );
  }
}
