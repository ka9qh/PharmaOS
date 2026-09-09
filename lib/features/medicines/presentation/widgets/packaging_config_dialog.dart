// حوار تهيئة وحدات البيع (شريط/باكت) لدواء معيّن - راجع
// core/services/medicine_packaging_service.dart

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/medicine_packaging_service.dart';

Future<void> showPackagingConfigDialog(
  BuildContext context, {
  required int medicineId,
  required String medicineName,
  required String baseUnitName,
}) async {
  final service = sl<MedicinePackagingService>();
  final existing = await service.getConfig(medicineId);

  bool hasMiddle = existing?.hasMiddleLevel ?? false;
  bool hasLarge = existing?.hasLargeLevel ?? false;
  final middleNameController = TextEditingController(text: existing?.middleUnitName ?? 'شريط');
  final unitsPerMiddleController =
      TextEditingController(text: existing?.unitsPerMiddle?.toString() ?? '10');
  final largeNameController = TextEditingController(text: existing?.largeUnitName ?? 'باكت');
  final middlesPerLargeController =
      TextEditingController(text: existing?.middlesPerLarge?.toString() ?? '10');

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('وحدات البيع: $medicineName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الوحدة الأساسية: $baseUnitName (ثابتة، تُباع دائمًا)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 24),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('يُباع أيضًا بوحدة وسطى (مثل: شريط)'),
                value: hasMiddle,
                onChanged: (v) => setState(() => hasMiddle = v ?? false),
              ),
              if (hasMiddle) ...[
                TextField(
                  controller: middleNameController,
                  decoration: const InputDecoration(labelText: 'اسم الوحدة الوسطى (مثال: شريط)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: unitsPerMiddleController,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: 'عدد $baseUnitName في الوحدة الوسطى الواحدة'),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('يُباع أيضًا بوحدة كبرى (مثل: باكت/كرتون)'),
                  value: hasLarge,
                  onChanged: (v) => setState(() => hasLarge = v ?? false),
                ),
                if (hasLarge) ...[
                  TextField(
                    controller: largeNameController,
                    decoration:
                        const InputDecoration(labelText: 'اسم الوحدة الكبرى (مثال: باكت)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: middlesPerLargeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'عدد ${middleNameController.text} في الوحدة الكبرى الواحدة'),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (!hasMiddle) {
                await service.clearConfig(medicineId);
              } else {
                await service.setConfig(MedicinePackagingConfig(
                  medicineId: medicineId,
                  middleUnitName: middleNameController.text.trim().isEmpty
                      ? 'شريط'
                      : middleNameController.text.trim(),
                  unitsPerMiddle: int.tryParse(unitsPerMiddleController.text) ?? 1,
                  largeUnitName: hasLarge
                      ? (largeNameController.text.trim().isEmpty
                          ? 'باكت'
                          : largeNameController.text.trim())
                      : null,
                  middlesPerLarge: hasLarge ? (int.tryParse(middlesPerLargeController.text) ?? 1) : null,
                ));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}
