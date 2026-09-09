import 'package:flutter/material.dart';
import '../../domain/entities/inventory_entity.dart';

class StockRow extends StatelessWidget {
  final StockSummary stock;
  final VoidCallback onReceiveStock;
  final VoidCallback onPrintBarcode;
  final VoidCallback onWriteOff;

  const StockRow({
    super.key,
    required this.stock,
    required this.onReceiveStock,
    required this.onPrintBarcode,
    required this.onWriteOff,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        stock.isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
        color: stock.isLow ? Colors.red : null,
      ),
      title: Text(stock.medicineName),
      subtitle: Text(
        'الكمية الحالية: ${stock.formattedQuantity ?? stock.totalQuantity}  •  حد التنبيه: ${stock.reorderLevel}',
        style: TextStyle(color: stock.isLow ? Colors.red : null),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'طباعة الباركود',
            onPressed: onPrintBarcode,
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
            tooltip: 'إتلاف / خصم',
            onPressed: onWriteOff,
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'استلام كمية جديدة',
            onPressed: onReceiveStock,
          ),
        ],
      ),
    );
  }
}
