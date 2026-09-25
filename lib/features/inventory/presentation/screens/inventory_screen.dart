// شاشة نظرة عامة على المخزون (أدوية الصيدلية المتوفرة فعلياً)
// تشمل: البحث الفوري، الحساب الهرمي للكميات، طباعة الباركود، إضافة أدوية للمخزون، وعرض جدولي وبطاقات تفاعلية سريعة

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/inventory_provider.dart';
import '../widgets/inventory_widget.dart';
import '../widgets/receive_stock_dialog.dart';
import '../../../barcode/presentation/widgets/scan_medicine_barcode_dialog.dart';
import '../../domain/entities/inventory_entity.dart';
import '../../../../core/security/role_guard.dart';
import '../../../../core/di/service_locator.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../medicines/presentation/providers/medicines_provider.dart';
import '../../../medicines/presentation/screens/medicine_form_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  bool _isTableView = true;

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
                      labelText: 'الكمية المراد إتلافها (بالحبة)',
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
    await ScanMedicineBarcodeDialog.show(
      context,
      medicineId: stock.medicineId,
      medicineName: stock.medicineName,
      currentBarcode: stock.barcode,
      sellingPrice: stock.packSellingPrice ?? stock.sellingPrice,
      onBarcodeSaved: (newBarcode) async {
        final medRepo = sl<MedicinesRepository>();
        final med = await medRepo.getById(stock.medicineId);
        if (med != null) {
          final updated = med.copyWith(barcode: newBarcode);
          final ok = await ref.read(medicinesNotifierProvider.notifier).updateMedicine(updated);
          if (ok) {
            await ref.read(inventoryNotifierProvider.notifier).loadAll();
            return true;
          }
        }
        return false;
      },
    );
  }

  void _openEditMedicine(StockSummary stock) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineFormScreen(existing: stock.toMedicineEntity()),
      ),
    ).then((_) {
      ref.read(inventoryNotifierProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryNotifierProvider);
    final totalItemsCount = state.items.length;
    final lowStockCount = state.items.where((s) => s.isLow).length;

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
                      const Spacer(),
                      // زر التبديل بين العرض الجدولي وعرض البطاقات
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.table_chart, color: _isTableView ? Colors.blue.shade900 : Colors.grey),
                              tooltip: 'جدول تفصيلي',
                              onPressed: () => setState(() => _isTableView = true),
                            ),
                            IconButton(
                              icon: Icon(Icons.view_agenda_outlined, color: !_isTableView ? Colors.blue.shade900 : Colors.grey),
                              tooltip: 'بطاقات سريعة',
                              onPressed: () => setState(() => _isTableView = false),
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
                      : _isTableView
                          ? _buildTableView(state.items)
                          : _buildCardListView(state.items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardListView(List<StockSummary> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final stock = items[index];
        return StockCard(
          stock: stock,
          onReceiveStock: () => _showReceiveStockDialog(context, stock.medicineId),
          onPrintBarcode: () => _showBarcodeDialog(context, stock),
          onWriteOff: () => _showWriteOffDialog(context, stock),
          onEdit: () => _openEditMedicine(stock),
          onDeleteBatch: () => _confirmRemoveFromInventory(context, stock),
        );
      },
    );
  }

  Widget _buildTableView(List<StockSummary> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1750, // العرض الكلي للجدول
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
                  SizedBox(width: 130, child: Text('رقم/باركود الصنف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 200, child: Text('اسم الدواء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 160, child: Text('الاسم الإنجليزي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 160, child: Text('الاسم العلمي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 130, child: Text('الشركة المصنعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 130, child: Text('المورد / الوكيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 110, child: Text('التعبئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 95, child: Text('سعر الباكت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 95, child: Text('سعر الشريط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 95, child: Text('سعر الحبة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 105, child: Text('تاريخ الانتهاء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 110, child: Text('الرصيد الفعلي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (ctx, idx) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final stock = items[index];

                    final packStr = stock.qtyPerPack != null && stock.qtyPerPack! > 0 ? '${stock.qtyPerPack} باكت' : '';
                    final stripStr = stock.qtyPerStrip != null && stock.qtyPerStrip! > 0 ? '${stock.qtyPerStrip} شريط' : '';
                    final packing = [packStr, stripStr].where((s) => s.isNotEmpty).join(' / ');

                    String detailedQty = '${stock.totalQuantity}';
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

                    final expiryDateStr = stock.expiryDate != null ? DateFormat('yyyy-MM-dd').format(stock.expiryDate!) : '-';
                    final isExpired = stock.expiryDate != null && stock.expiryDate!.isBefore(DateTime.now());

                    return InkWell(
                      onTap: () => _openEditMedicine(stock),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 130,
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
                              width: 160,
                              child: Text(stock.nameEn ?? '-', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                            SizedBox(
                              width: 160,
                              child: Text(stock.nameScientific ?? '-', style: const TextStyle(fontSize: 12, color: Colors.teal), overflow: TextOverflow.ellipsis),
                            ),
                            SizedBox(
                              width: 130,
                              child: Text(stock.companyName ?? '-', style: const TextStyle(fontSize: 12, color: Colors.indigo), overflow: TextOverflow.ellipsis),
                            ),
                            SizedBox(
                              width: 130,
                              child: Text(stock.supplierName ?? '-', style: const TextStyle(fontSize: 12, color: Colors.purple), overflow: TextOverflow.ellipsis),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(packing.isNotEmpty ? packing : stock.unit, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                            SizedBox(
                              width: 95,
                              child: Text(
                                stock.packSellingPrice != null && stock.packSellingPrice! > 0 ? stock.packSellingPrice!.toStringAsFixed(0) : '-',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 95,
                              child: Text(
                                stock.stripSellingPrice != null && stock.stripSellingPrice! > 0 ? stock.stripSellingPrice!.toStringAsFixed(0) : '-',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 95,
                              child: Text(
                                stock.sellingPrice.toStringAsFixed(0),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 105,
                              child: Text(
                                expiryDateStr,
                                style: TextStyle(color: isExpired ? Colors.red : Colors.black87, fontSize: 12, fontWeight: isExpired ? FontWeight.bold : FontWeight.normal),
                              ),
                            ),
                            SizedBox(
                              width: 110,
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
                                    fontSize: 12,
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
                                    onPressed: () => _openEditMedicine(stock),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner, size: 20, color: Colors.teal),
                                    tooltip: 'قراءة ومسح باركود الشركة',
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
                                    icon: const Icon(Icons.delete_sweep, size: 20, color: Colors.orange),
                                    tooltip: 'إتلاف كمية',
                                    onPressed: () => _showWriteOffDialog(context, stock),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                                    tooltip: 'إزالة الدفعة من المخزون',
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
    );
  }
}
