import 'package:flutter/material.dart';
import '../../domain/entities/pos_entity.dart';
import '../../../medicines/presentation/widgets/medicine_clinical_details_dialog.dart';
import '../../../../core/services/medicine_clinical_helper.dart';
import 'select_batch_dialog.dart';

class CartItemRow extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<double>? onPriceChanged;
  final void Function(int?, DateTime?)? onBatchChanged;
  final VoidCallback onRemove;
  final VoidCallback onUnitChangeRequested;
  final VoidCallback? onFindAlternatives;

  final int index;

  const CartItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.onQuantityChanged,
    this.onPriceChanged,
    this.onBatchChanged,
    required this.onRemove,
    required this.onUnitChangeRequested,
    this.onFindAlternatives,
  });

  void _showEditPriceDialog(BuildContext context) {
    final ctrl = TextEditingController(text: item.unitPrice.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text('تعديل سعر البيع: ${item.medicineName}', style: const TextStyle(fontSize: 15))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('السعر الحالي: ${item.unitPrice.toStringAsFixed(0)} ر.ي / ${item.selectedUnitName}',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر الجديد (ريال)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                final val = double.tryParse(ctrl.text.trim());
                if (val != null && val >= 0) {
                  onPriceChanged?.call(val);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ السعر'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditQuantityDialog(BuildContext context) {
    final ctrl = TextEditingController(text: '${item.selectedQuantity}');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.format_list_numbered, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('تعديل الكمية: ${item.medicineName}', style: const TextStyle(fontSize: 15))),
            ],
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'الكمية المطلوبة (${item.selectedUnitName})',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.numbers),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final val = int.tryParse(ctrl.text.trim());
                if (val != null && val > 0) {
                  onQuantityChanged(val);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('تطبيق الكمية'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExpiryDialog(BuildContext context) {
    showSelectBatchDialog(
      context: context,
      medicineId: item.medicineId,
      medicineName: item.medicineName,
      onSelect: (batchId, expiryDate) {
        onBatchChanged?.call(batchId, expiryDate);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEven = index % 2 == 0;
    final preg = MedicineClinicalHelper.getPregnancySafety(medicineName: item.medicineName);
    final card = MedicineClinicalHelper.getCardiacSafety(medicineName: item.medicineName);

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          SizedBox(
            width: 250,
            child: InkWell(
              onTap: () => MedicineClinicalDetailsDialog.show(
                context,
                medicineId: item.medicineId,
                fallbackName: item.medicineName,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.medicineName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!preg.isSafe) ...[
                    const SizedBox(width: 3),
                    Tooltip(
                      message: 'تحذير الحوامل: ${preg.statusLabel}\nالبديل: ${preg.safeAlternative}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade300, width: 0.8),
                        ),
                        child: const Text('🤰⚠️', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                  if (!card.isSafe) ...[
                    const SizedBox(width: 3),
                    Tooltip(
                      message: 'تحذير مرضى القلب والضغط: ${card.statusLabel}\nالبديل: ${card.safeAlternative}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade300, width: 0.8),
                        ),
                        child: const Text('❤️⚠️', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, size: 16, color: Colors.teal),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: InkWell(
              onTap: onUnitChangeRequested,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.selectedUnitName,
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 14, color: Colors.blue.shade800),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: InkWell(
              onTap: () => _showEditPriceDialog(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.unitPrice.toStringAsFixed(0)} ر.ي',
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 12, color: Colors.blueGrey),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16, color: Colors.redAccent),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onQuantityChanged(item.selectedQuantity - 1),
                  ),
                  InkWell(
                    onTap: () => _showEditQuantityDialog(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        '${item.selectedQuantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16, color: Colors.green),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onQuantityChanged(item.selectedQuantity + 1),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 130,
            child: InkWell(
              onTap: () => _showEditExpiryDialog(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.batchId != null 
                          ? (item.expiryDate != null ? '${item.expiryDate!.year}-${item.expiryDate!.month.toString().padLeft(2, '0')}' : 'دفعة مخصصة')
                          : 'تلقائي (FEFO)',
                      style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.date_range, size: 12, color: Colors.amber),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              '${item.subtotal.toStringAsFixed(0)} ر.ي',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onFindAlternatives != null)
                  IconButton(
                    icon: const Icon(Icons.swap_horizontal_circle_outlined, size: 20, color: Color(0xFF10B981)),
                    onPressed: onFindAlternatives,
                    tooltip: 'البدائل العلمية والمخزنية المتوفرة',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: onRemove,
                  tooltip: 'حذف من السلة',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
