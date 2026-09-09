import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/medicine_units_service.dart';
import '../../domain/entities/medicines_entity.dart';

Future<void> showUnitHierarchyDialog(
  BuildContext context, {
  required MedicineEntity medicine,
}) async {
  final service = sl<MedicineUnitsService>();
  final existingUnits = await service.getUnits(medicine.id);

  if (!context.mounted) return;

  if (medicine.medicineType == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('الرجاء تحديد نوع الدواء أولاً من شاشة التعديل')),
    );
    return;
  }

  // توليد المستويات الافتراضية بناءً على النوع إذا لم تكن موجودة
  List<MedicineUnitConfig> units = [];
  if (existingUnits.isNotEmpty) {
    units = List.from(existingUnits);
  } else {
    if (medicine.medicineType == 1) { // حبوب
      units = [
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 1, unitName: 'حبة', multiplier: 1, purchasePrice: medicine.purchasePrice, sellingPrice: medicine.sellingPrice),
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 2, unitName: 'شريط', multiplier: medicine.qtyPerStrip ?? 10),
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 3, unitName: 'علبة', multiplier: (medicine.qtyPerPack != null && medicine.qtyPerStrip != null && medicine.qtyPerStrip != 0) ? (medicine.qtyPerPack! ~/ medicine.qtyPerStrip!) : 3),
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 4, unitName: 'كرتون', multiplier: 50),
      ];
    } else if (medicine.medicineType == 2) { // حقن
      units = [
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 1, unitName: 'أمبولة', multiplier: 1, purchasePrice: medicine.purchasePrice, sellingPrice: medicine.sellingPrice),
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 2, unitName: 'علبة', multiplier: medicine.qtyPerPack ?? 5),
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 3, unitName: 'كرتون', multiplier: 50),
      ];
    } else if (medicine.medicineType == 3) { // زجاجات
      units = [
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 1, unitName: 'زجاجة', multiplier: 1, purchasePrice: medicine.purchasePrice, sellingPrice: medicine.sellingPrice),
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 2, unitName: 'كرتون', multiplier: 24),
      ];
    } else if (medicine.medicineType == 4) { // حفاضات
      units = [
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 1, unitName: 'حبة', multiplier: 1, purchasePrice: medicine.purchasePrice, sellingPrice: medicine.sellingPrice),
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 2, unitName: 'كيس كامل', multiplier: medicine.qtyPerPack ?? 40),
      ];
    } else if (medicine.medicineType == 5) { // مستحضرات
      units = [
        MedicineUnitConfig(id: 0, medicineId: medicine.id, levelOrder: 1, unitName: 'قطعة', multiplier: 1, purchasePrice: medicine.purchasePrice, sellingPrice: medicine.sellingPrice),
      ];
    }
  }

  await showDialog(
    context: context,
    builder: (context) => _UnitHierarchyDialogContent(
      medicine: medicine,
      initialUnits: units,
      service: service,
    ),
  );
}

class _UnitHierarchyDialogContent extends StatefulWidget {
  final MedicineEntity medicine;
  final List<MedicineUnitConfig> initialUnits;
  final MedicineUnitsService service;

  const _UnitHierarchyDialogContent({
    required this.medicine,
    required this.initialUnits,
    required this.service,
  });

  @override
  State<_UnitHierarchyDialogContent> createState() => _UnitHierarchyDialogContentState();
}

class _UnitHierarchyDialogContentState extends State<_UnitHierarchyDialogContent> {
  late List<Map<String, dynamic>> _unitsData;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _unitsData = widget.initialUnits.map((u) => {
      'id': u.id,
      'levelOrder': u.levelOrder,
      'unitName': TextEditingController(text: u.unitName),
      'multiplier': TextEditingController(text: u.multiplier.toString()),
      'purchasePrice': TextEditingController(text: u.purchasePrice?.toString() ?? ''),
      'sellingPrice': TextEditingController(text: u.sellingPrice?.toString() ?? ''),
    }).toList();
  }

  @override
  void dispose() {
    for (var u in _unitsData) {
      u['unitName'].dispose();
      u['multiplier'].dispose();
      u['purchasePrice'].dispose();
      u['sellingPrice'].dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    
    final newUnits = _unitsData.map((u) => MedicineUnitConfig(
      id: u['id'],
      medicineId: widget.medicine.id,
      levelOrder: u['levelOrder'],
      unitName: u['unitName'].text.trim(),
      multiplier: int.tryParse(u['multiplier'].text) ?? 1,
      purchasePrice: double.tryParse(u['purchasePrice'].text),
      sellingPrice: double.tryParse(u['sellingPrice'].text),
    )).toList();

    await widget.service.saveUnits(widget.medicine.id, newUnits);
    
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تسعير وهيكلة الوحدات: ${widget.medicine.nameAr}'),
      content: SizedBox(
        width: 500, // Fixed width to prevent overflow
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _unitsData.length,
          separatorBuilder: (context, index) => const Divider(height: 32),
          itemBuilder: (context, index) {
            final u = _unitsData[index];
            final prevUnitName = index > 0 ? _unitsData[index - 1]['unitName'].text : '';
            final isBase = index == 0;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المستوى ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: u['unitName'],
                        decoration: const InputDecoration(labelText: 'اسم الوحدة'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: u['multiplier'],
                        keyboardType: TextInputType.number,
                        enabled: !isBase,
                        decoration: InputDecoration(
                          labelText: isBase ? 'المعامل (ثابت)' : 'كم يحتوي من ($prevUnitName)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: u['purchasePrice'],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'سعر الشراء'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: u['sellingPrice'],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'سعر البيع'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ الإعدادات'),
        ),
      ],
    );
  }
}
