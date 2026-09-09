import 'package:flutter/material.dart';
import '../../domain/entities/stock_alerts_entity.dart';

class LowStockTile extends StatelessWidget {
  final StockSummary item;
  const LowStockTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
      title: Text(item.medicineName),
      subtitle: Text('ط§ظ„ظ…طھط¨ظ‚ظٹ: ${item.totalQuantity} â€¢ ط­ط¯ ط§ظ„طھظ†ط¨ظٹظ‡: ${item.reorderLevel}'),
    );
  }
}
