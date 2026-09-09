import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../inventory/domain/entities/inventory_entity.dart';
import '../../../inventory/domain/repositories/inventory_repository.dart';
import 'package:intl/intl.dart' hide TextDirection;

Future<void> showSelectBatchDialog({
  required BuildContext context,
  required int medicineId,
  required String medicineName,
  required void Function(int? batchId, DateTime? expiryDate) onSelect,
}) async {
  final batches = await sl<InventoryRepository>().getBatchesForMedicine(medicineId);

  if (!context.mounted) return;

  if (batches.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لا توجد دفعات متوفرة في المخزون لهذا الصنف')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (ctx) => _SelectBatchDialogContent(
      medicineName: medicineName,
      batches: batches,
      onSelect: (batchId, expiryDate) {
        onSelect(batchId, expiryDate);
        Navigator.pop(ctx);
      },
    ),
  );
}

class _SelectBatchDialogContent extends StatelessWidget {
  final String medicineName;
  final List<BatchEntity> batches;
  final void Function(int? batchId, DateTime? expiryDate) onSelect;

  const _SelectBatchDialogContent({
    super.key,
    required this.medicineName,
    required this.batches,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text('تحديد دفعة الصرف: $medicineName', style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر الدفعة التي سيتم الخصم منها (تلقائي = الأقرب انتهاءً)', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
              const SizedBox(height: 12),
              
              // Option for Auto (FEFO)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
                title: const Text('تحديد تلقائي (FEFO)'),
                subtitle: const Text('الخصم من الدفعة الأقرب انتهاءً بشكل آلي'),
                onTap: () => onSelect(null, null),
              ),
              const Divider(),
              
              // Available batches
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: batches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    final expiryStr = batch.expiryDate != null 
                        ? DateFormat('yyyy-MM-dd').format(batch.expiryDate!)
                        : 'غير محدد';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF1F5F9), 
                        child: Icon(Icons.date_range, color: Colors.blueGrey, size: 18),
                      ),
                      title: Text('تاريخ الانتهاء: $expiryStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('رقم الدفعة: ${batch.batchNumber ?? "بدون"} | الكمية المتوفرة: ${batch.quantity}', 
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      onTap: () => onSelect(batch.id, batch.expiryDate),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ],
      ),
    );
  }
}
