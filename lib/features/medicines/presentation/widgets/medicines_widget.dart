import 'package:flutter/material.dart';
import '../../domain/entities/medicines_entity.dart';

class MedicineListTile extends StatelessWidget {
  final MedicineEntity medicine;
  final VoidCallback onPrintBarcode;
  final VoidCallback onConfigurePackaging;
  final VoidCallback onEdit;

  const MedicineListTile({
    super.key,
    required this.medicine,
    required this.onPrintBarcode,
    required this.onConfigurePackaging,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.medication_outlined),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'رقم: ',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(medicine.nameAr)),
        ],
      ),
      subtitle: Text(
        '${medicine.companyName ?? 'بدون شركة'} • ${medicine.sellingPrice.toStringAsFixed(0)} ريال',
      ),
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'وحدات البيع (حبة/شريط/باكت)',
            onPressed: onConfigurePackaging,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'عرض/طباعة الباركود',
            onPressed: onPrintBarcode,
          ),
        ],
      ),
    );
  }
}
