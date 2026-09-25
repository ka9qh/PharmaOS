import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/inventory_entity.dart';

class StockCard extends StatelessWidget {
  final StockSummary stock;
  final VoidCallback onReceiveStock;
  final VoidCallback onPrintBarcode;
  final VoidCallback onWriteOff;
  final VoidCallback onEdit;
  final VoidCallback onDeleteBatch;

  const StockCard({
    super.key,
    required this.stock,
    required this.onReceiveStock,
    required this.onPrintBarcode,
    required this.onWriteOff,
    required this.onEdit,
    required this.onDeleteBatch,
  });

  @override
  Widget build(BuildContext context) {
    final packStr = stock.qtyPerPack != null && stock.qtyPerPack! > 0 ? '${stock.qtyPerPack} باكت' : '';
    final stripStr = stock.qtyPerStrip != null && stock.qtyPerStrip! > 0 ? '${stock.qtyPerStrip} شريط' : '';
    final packing = [packStr, stripStr].where((s) => s.isNotEmpty).join(' / ');

    String detailedQty = '${stock.totalQuantity} حبة';
    final qStrip = stock.qtyPerStrip ?? 1;
    final qPack = stock.qtyPerPack ?? 1;
    if (qStrip > 0 && qPack > 0) {
      final pillsPerPack = qPack * qStrip;
      final packs = stock.totalQuantity ~/ pillsPerPack;
      final remainingAfterPack = stock.totalQuantity % pillsPerPack;
      final strips = remainingAfterPack ~/ qStrip;
      final pills = remainingAfterPack % qStrip;

      List<String> parts = [];
      if (packs > 0) parts.add('$packs باكت');
      if (strips > 0) parts.add('$strips شريط');
      if (pills > 0 || (packs == 0 && strips == 0)) parts.add('$pills حبة');
      detailedQty = parts.join(' و ');
    }

    final isExpired = stock.expiryDate != null && stock.expiryDate!.isBefore(DateTime.now());
    final isExpiringSoon = stock.expiryDate != null &&
        !isExpired &&
        stock.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 90)));

    final expiryStr = stock.expiryDate != null ? DateFormat('yyyy-MM-dd').format(stock.expiryDate!) : 'بدون تاريخ';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: stock.isLow ? Colors.red.shade200 : Colors.grey.shade200,
          width: stock.isLow ? 1.5 : 1,
        ),
      ),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // أيقونة المخزون والحالة
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: stock.isLow ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                stock.isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                color: stock.isLow ? Colors.red.shade700 : Colors.blue.shade700,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),

            // تفاصيل الدواء
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stock.medicineName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: stock.isLow ? Colors.red.shade900 : const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (stock.barcode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            stock.barcode,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (stock.nameEn != null && stock.nameEn!.isNotEmpty)
                        Text(
                          stock.nameEn!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      if (stock.nameScientific != null && stock.nameScientific!.isNotEmpty)
                        Text(
                          '•  ${stock.nameScientific!}',
                          style: const TextStyle(fontSize: 12, color: Colors.teal),
                        ),
                      if (stock.companyName != null && stock.companyName!.isNotEmpty)
                        Text(
                          '•  ${stock.companyName!}',
                          style: const TextStyle(fontSize: 12, color: Colors.indigo),
                        ),
                      if (packing.isNotEmpty)
                        Text(
                          '•  $packing',
                          style: const TextStyle(fontSize: 12, color: Colors.purple),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // شارة الرصيد
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: stock.isLow ? Colors.red.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: stock.isLow ? Colors.red.shade200 : Colors.blue.shade200),
                        ),
                        child: Text(
                          'الكمية الحالية: $detailedQty (${stock.totalQuantity} حبة)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: stock.isLow ? Colors.red.shade800 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                      // تاريخ الانتهاء
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? Colors.red.shade50
                              : (isExpiringSoon ? Colors.orange.shade50 : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isExpired
                                ? Colors.red.shade300
                                : (isExpiringSoon ? Colors.orange.shade300 : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 13,
                              color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'الانتهاء: $expiryStr',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isExpired || isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                                color: isExpired
                                    ? Colors.red
                                    : (isExpiringSoon ? Colors.orange.shade900 : Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // الأسعار
                      if (stock.sellingPrice > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            'سعر الحبة: ${stock.sellingPrice.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          ),
                        ),
                      if (stock.packSellingPrice != null && stock.packSellingPrice! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.indigo.shade200),
                          ),
                          child: Text(
                            'سعر الباكت: ${stock.packSellingPrice!.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // أزرار الإجراءات السريعة
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_box_rounded, color: Colors.green, size: 24),
                  tooltip: 'استلام / إضافة كمية',
                  onPressed: onReceiveStock,
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 22),
                  tooltip: 'إتلاف / خصم',
                  onPressed: onWriteOff,
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code, color: Colors.teal, size: 22),
                  tooltip: 'طباعة الباركود',
                  onPressed: onPrintBarcode,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 22),
                  tooltip: 'تعديل بيانات الدواء',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  tooltip: 'حذف/تصفير الدفعة',
                  onPressed: onDeleteBatch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    return StockCard(
      stock: stock,
      onReceiveStock: onReceiveStock,
      onPrintBarcode: onPrintBarcode,
      onWriteOff: onWriteOff,
      onEdit: () {},
      onDeleteBatch: () {},
    );
  }
}
