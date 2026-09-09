// شاشة نظرة عامة على المخزون (أدوية الصيدلية المتوفرة فعلياً)
// تشمل: البحث الفوري، الحساب الهرمي للكميات، طباعة الباركود، وإضافة أدوية للمخزون

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/inventory_provider.dart';
import '../widgets/inventory_widget.dart';
import '../widgets/receive_stock_dialog.dart';
import '../../../medicines/presentation/providers/medicines_provider.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/medicine_units_service.dart';
import '../../../../core/hardware/label_printer_service.dart';
import '../../../../core/hardware/label_printer_service.dart';
import '../../../barcode/presentation/widgets/barcode_widget.dart';
import '../../domain/entities/inventory_entity.dart';
import '../../../../core/security/role_guard.dart';
import '../../../medicines/presentation/screens/medicine_form_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showReceiveStockDialog(BuildContext context, [int? medicineId]) {
    showDialog(
      context: context,
      builder: (_) => ReceiveStockDialog(initialMedicineId: medicineId),
    ).then((_) {
      ref.read(inventoryNotifierProvider.notifier).loadAll();
    });
  }

  void _showWriteOffDialog(BuildContext context, StockSummary stock) {
    RoleGuard.checkPermission(
      context: context,
      ref: ref,
      permission: AppPermission.editInventory,
      onGranted: () {
        final qtyController = TextEditingController();
        final reasonController = TextEditingController(text: 'تالف/منتهي الصلاحية');
        
        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.delete_sweep, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text('إتلاف صنف: ${stock.medicineName}')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الكمية المتوفرة: ${stock.totalQuantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الكمية المراد إتلافها',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'سبب الإتلاف (إلزامي)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('تأكيد الإتلاف'),
                  onPressed: () async {
                    final qty = int.tryParse(qtyController.text) ?? 0;
                    final reason = reasonController.text.trim();
                    
                    if (qty <= 0 || qty > stock.totalQuantity) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('كمية غير صالحة')));
                      return;
                    }
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الرجاء إدخال السبب')));
                      return;
                    }
                    
                    final success = await ref.read(inventoryNotifierProvider.notifier).writeOffStock(
                      medicineId: stock.medicineId,
                      quantity: qty,
                      reason: reason,
                    );
                    
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Colors.green, content: Text('تم تسجيل الإتلاف بنجاح')),
                        );
                      } else {
                        final error = ref.read(inventoryNotifierProvider).errorMessage;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: Colors.red, content: Text(error ?? 'فشل الإتلاف')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveFromInventory(BuildContext context, StockSummary stock) {
    RoleGuard.checkPermission(
      context: context,
      ref: ref,
      permission: AppPermission.editInventory,
      onGranted: () {
        final expiryStr = stock.expiryDate != null ? DateFormat('yyyy-MM-dd').format(stock.expiryDate!) : 'بدون تاريخ';
        final batchStr = stock.batchNumber != null && stock.batchNumber!.isNotEmpty ? ' (تشغيلة: ${stock.batchNumber})' : '';

        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(child: Text('إزالة الدفعة المحددة من المخزون')),
                ],
              ),
              content: Text(
                'هل أنت متأكد من إزالة هذه الدفعة المحددة فقط للصنف "${stock.medicineName}"؟\n\n'
                '• تاريخ الانتهاء: $expiryStr$batchStr\n'
                '• الكمية في هذا السطر: ${stock.totalQuantity}\n\n'
                'ملاحظة: هذا الإجراء سيقوم بحذف/تصفير هذه الدفعة فقط دون المساس بأي دفعات أو تواريخ أخرى لنفس الدواء.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.delete),
                  label: const Text('نعم، قم بإزالة هذه الدفعة'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final bool success;
                    if (stock.batchId != null) {
                      success = await ref.read(inventoryNotifierProvider.notifier).deleteSingleBatch(stock.batchId!);
                    } else {
                      success = await ref.read(inventoryNotifierProvider.notifier).deleteStockRecords(stock.medicineId);
                    }
                    if (context.mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Colors.green, content: Text('تم إزالة الدفعة المحددة من المخزون بنجاح')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Colors.red, content: Text('حدث خطأ أثناء الإزالة')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBarcodeDialog(BuildContext context, StockSummary stock) async {
    final medicines = ref.read(medicinesNotifierProvider).items;
    final medicine = medicines.where((m) => m.id == stock.medicineId).firstOrNull;
    if (medicine == null) return;

    // حساب عدد النسخ الافتراضي: الكمية الكلية مقسومة على معامل الباكت
    int defaultCopies = 1;
    if (stock.totalQuantity > 0) {
      final units = await sl<MedicineUnitsService>().getUnits(medicine.id);
      final packUnit = units.where((u) => u.levelOrder == 2).firstOrNull;
      if (packUnit != null && packUnit.multiplier > 0) {
        defaultCopies = stock.totalQuantity ~/ packUnit.multiplier;
        if (defaultCopies == 0) defaultCopies = 1;
      } else {
        defaultCopies = stock.totalQuantity;
      }
    }

    final copiesController = TextEditingController(text: defaultCopies.toString());

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text('طباعة باركود المخزون: ${medicine.nameAr}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BarcodeLabelPreview(
              barcodeValue: medicine.barcode,
              medicineName: medicine.nameAr,
            ),
            const SizedBox(height: 16),
            const Text(
              'تم حساب عدد النسخ افتراضياً بناءً على عدد العبوات/البواكت المتوفرة في المخزون.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: copiesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد النسخ (ملصقات الباركود)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.print),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('طباعة'),
            onPressed: () async {
              final copies = int.tryParse(copiesController.text) ?? 1;
              for (int i = 0; i < copies; i++) {
                await LabelPrinterService.printMedicineLabel(
                  medicineName: medicine.nameAr,
                  barcodeValue: medicine.barcode,
                  price: medicine.sellingPrice,
                );
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم إرسال $copies ملصق باركود للطباعة')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryNotifierProvider);
    final totalItemsCount = state.items.length;
    final lowStockCount = state.items.where((s) => s.totalQuantity <= 10).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('مخزون الصيدلية (الأدوية المتوفرة)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث المخزون',
              onPressed: () => ref.read(inventoryNotifierProvider.notifier).loadAll(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // بطاقة رأس الصفحة والبحث والإحصائيات
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Colors.blue),
                            hintText: 'ابحث في المخزون (بالاسم التجاري، العلمي، أو الباركود)...',
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(inventoryNotifierProvider.notifier).search('');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          onChanged: (val) => ref.read(inventoryNotifierProvider.notifier).search(val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('إضافة دواء لمخزون الصيدلية'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showReceiveStockDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'إجمالي الأصناف بالمخزون: $totalItemsCount صنف',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (lowStockCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                '$lowStockCount أصناف تحت حد التنبيه',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // قائمة أدوية المخزون
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text(
                                'لا توجد أدوية متوفرة في مخزون الصيدلية حالياً',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة أول دواء للمخزون الآن'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: () => _showReceiveStockDialog(context),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 1700, // العرض الكلي للجدول
                            child: Column(
                              children: [
                                // رأس الجدول
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade900,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(width: 120, child: Text('رقم/باركود الصنف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 200, child: Text('اسم الدواء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 150, child: Text('الاسم الإنجليزي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 150, child: Text('الاسم العلمي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 120, child: Text('الشركة المصنعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 120, child: Text('المورد / الوكيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 100, child: Text('التعبئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 90, child: Text('سعر الباكت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 90, child: Text('سعر الشريط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 90, child: Text('سعر الحبة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 90, child: Text('تاريخ الانتهاء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 90, child: Text('الرصيد الفعلي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      Expanded(child: Text('إجراءات', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                // بيانات الجدول
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: ListView.separated(
                                      itemCount: state.items.length,
                                      separatorBuilder: (ctx, idx) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final stock = state.items[index];
                                        final allMedicines = ref.read(medicinesNotifierProvider).items;
                                        final medEntity = allMedicines.where((m) => m.id == stock.medicineId).firstOrNull;
                                        final packStr = medEntity?.qtyPerPack != null && medEntity!.qtyPerPack! > 0 ? '${medEntity.qtyPerPack} باكت' : '';
                                        final stripStr = medEntity?.qtyPerStrip != null && medEntity!.qtyPerStrip! > 0 ? '${medEntity.qtyPerStrip} شريط' : '';
                                        final packing = [packStr, stripStr].where((s) => s.isNotEmpty).join(' / ');
                                        
                                        String detailedQty = '${stock.totalQuantity}';
                                        if (medEntity != null) {
                                          final qStrip = medEntity.qtyPerStrip ?? 1;
                                          final qPack = medEntity.qtyPerPack ?? 1;
                                          
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
                                        }
                                        
                                        final expiryDateStr = stock.expiryDate != null ? DateFormat('yyyy-MM-dd').format(stock.expiryDate!) : '-';
                                        
                                        return InkWell(
                                          onTap: () {
                                            if (medEntity != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => MedicineFormScreen(existing: medEntity),
                                                ),
                                              );
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 120,
                                                  child: Text(
                                                    stock.barcode.isNotEmpty ? stock.barcode : '${stock.medicineId}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 200,
                                                  child: Row(
                                                    children: [
                                                      if (stock.isLow)
                                                        const Padding(
                                                          padding: EdgeInsets.only(left: 4),
                                                          child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                                                        ),
                                                      Expanded(
                                                        child: Text(
                                                          stock.medicineName,
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: stock.isLow ? Colors.red : Colors.black87),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 150,
                                                  child: Text(medEntity?.nameEn ?? '-', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                                ),
                                                SizedBox(
                                                  width: 150,
                                                  child: Text(medEntity?.nameScientific ?? '-', style: const TextStyle(fontSize: 12, color: Colors.teal), overflow: TextOverflow.ellipsis),
                                                ),
                                                SizedBox(
                                                  width: 120,
                                                  child: Text(medEntity?.companyName ?? '-', style: const TextStyle(fontSize: 12, color: Colors.indigo), overflow: TextOverflow.ellipsis),
                                                ),
                                                SizedBox(
                                                  width: 120,
                                                  child: Text(medEntity?.supplierName ?? '-', style: const TextStyle(fontSize: 12, color: Colors.purple), overflow: TextOverflow.ellipsis),
                                                ),
                                                SizedBox(
                                                  width: 100,
                                                  child: Text(packing.isNotEmpty ? packing : (medEntity?.unit ?? 'باكت'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                                ),
                                                SizedBox(
                                                  width: 90,
                                                  child: Text('${medEntity?.packSellingPrice?.toStringAsFixed(0) ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13)),
                                                ),
                                                SizedBox(
                                                  width: 90,
                                                  child: Text('${medEntity?.stripSellingPrice?.toStringAsFixed(0) ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13)),
                                                ),
                                                SizedBox(
                                                  width: 90,
                                                  child: Text('${stock.sellingPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                                                ),
                                                SizedBox(
                                                  width: 90,
                                                  child: Text(expiryDateStr, style: TextStyle(color: stock.expiryDate != null && stock.expiryDate!.isBefore(DateTime.now()) ? Colors.red : Colors.black87, fontSize: 12)),
                                                ),
                                                SizedBox(
                                                  width: 90,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: stock.isLow ? Colors.red.shade50 : Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      detailedQty,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: stock.isLow ? Colors.red.shade900 : Colors.blue.shade900,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                                        tooltip: 'تعديل الصنف',
                                                        onPressed: () {
                                                          if (medEntity != null) {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (_) => MedicineFormScreen(existing: medEntity),
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: const Icon(Icons.qr_code, size: 20),
                                                        tooltip: 'طباعة الباركود',
                                                        onPressed: () => _showBarcodeDialog(context, stock),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: const Icon(Icons.add_box_outlined, size: 20, color: Colors.green),
                                                        tooltip: 'إضافة كمية للمخزون',
                                                        onPressed: () => _showReceiveStockDialog(context, stock.medicineId),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                                                        tooltip: 'إزالة من المخزون',
                                                        onPressed: () => _confirmRemoveFromInventory(context, stock),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
