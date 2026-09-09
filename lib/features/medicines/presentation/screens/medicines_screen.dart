// شاشة قائمة الأدوية (دليل أدوية السوق اليمني الشامل - أكثر من 30,000 دواء)
// جداول متقدمة + بحث فوري + تعديل + إضافة للمخزون + طباعة باركود

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/medicines_provider.dart';
import '../widgets/unit_hierarchy_dialog.dart';
import '../widgets/medicine_clinical_details_dialog.dart';
import '../widgets/assign_box_barcode_dialog.dart';
import 'medicine_form_screen.dart';
import '../../../barcode/presentation/widgets/barcode_widget.dart';
import '../../../../core/hardware/label_printer_service.dart';
import '../../../inventory/presentation/widgets/receive_stock_dialog.dart';
import '../../../settings/presentation/screens/medicine_import_screen.dart';
import '../../../../core/security/role_guard.dart';

enum MedicinesFilter { all, cosmeticsAndDiapers, incomplete }

class MedicinesScreen extends ConsumerStatefulWidget {
  final MedicinesFilter filter;
  const MedicinesScreen({super.key, this.filter = MedicinesFilter.all});

  @override
  ConsumerState<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends ConsumerState<MedicinesScreen> {
  late MedicinesFilter _activeFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.filter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showBarcodeDialog(BuildContext context, dynamic medicine) {
    final copiesController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text('طباعة باركود: ${medicine.nameAr}', style: const TextStyle(fontSize: 16))),
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
            TextField(
              controller: copiesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد النسخ المراد طباعتها',
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
            label: const Text('طباعة الباركود'),
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
                  SnackBar(content: Text('تم إرسال $copies ملصق للطباعة')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: const Row(
        children: [
          SizedBox(width: 60, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 130, child: Text('الباركود', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 240, child: Text('الاسم التجاري (عربي)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 220, child: Text('الاسم بالإنجليزية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 200, child: Text('الاسم العلمي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 160, child: Text('الشركة المصنعة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 160, child: Text('المورد / الوكيل', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 110, child: Text('الوحدة والتعبئة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 100, child: Text('سعر الشراء', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 100, child: Text('سعر البيع', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 220, child: Text('الإجراءات', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, WidgetRef ref, dynamic medicine, int index) {
    final isEven = index % 2 == 0;
    final packStr = medicine.qtyPerPack != null && medicine.qtyPerPack! > 0 ? '${medicine.qtyPerPack} باكت' : '';
    final stripStr = medicine.qtyPerStrip != null && medicine.qtyPerStrip! > 0 ? '${medicine.qtyPerStrip} شريط' : '';
    final packing = [packStr, stripStr].where((s) => s.isNotEmpty).join(' / ');

    final hasMissingData = (medicine.nameEn == null || medicine.nameEn!.isEmpty) ||
        (medicine.nameScientific == null || medicine.nameScientific!.isEmpty) ||
        (medicine.companyName == null || medicine.companyName!.isEmpty) ||
        (medicine.supplierName == null || medicine.supplierName!.isEmpty);

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '${medicine.id}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          SizedBox(
            width: 130,
            child: Row(
              children: [
                const Icon(Icons.qr_code, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    medicine.barcode,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 240,
            child: InkWell(
              onTap: () => MedicineClinicalDetailsDialog.show(
                context,
                medicineId: medicine.id,
                fallbackName: medicine.nameAr,
              ),
              child: Row(
                children: [
                  if (hasMissingData)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    ),
                  Expanded(
                    child: Text(
                      medicine.nameAr,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.receipt_long, size: 14, color: Colors.teal),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: Text(
              medicine.nameEn ?? '-',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 200,
            child: Text(
              medicine.nameScientific ?? '-',
              style: const TextStyle(fontSize: 12, color: Colors.teal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 160,
            child: Text(
              medicine.companyName ?? '-',
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 160,
            child: Text(
              medicine.supplierName ?? '-',
              style: const TextStyle(fontSize: 12, color: Colors.purple),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              packing.isNotEmpty ? packing : (medicine.unit ?? 'باكت'),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '${medicine.purchasePrice.toStringAsFixed(0)} ر.ي',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '${medicine.sellingPrice.toStringAsFixed(0)} ر.ي',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
          SizedBox(
            width: 250,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.receipt_long, color: Colors.teal, size: 20),
                  tooltip: 'الوصفة الطبية، جرعات الأطفال والبالغين، التحذيرات والبدائل',
                  onPressed: () => MedicineClinicalDetailsDialog.show(
                    context,
                    medicineId: medicine.id,
                    fallbackName: medicine.nameAr,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart, color: Colors.green, size: 20),
                  tooltip: 'إضافة لمخزون الصيدلية',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ReceiveStockDialog(initialMedicineId: medicine.id),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  tooltip: 'تعديل كافة البيانات',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MedicineFormScreen(existing: medicine),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF3B82F6), size: 20),
                  tooltip: 'ربط وتعديل باركود العلبة بالقارئ',
                  onPressed: () async {
                    final res = await AssignBoxBarcodeDialog.show(
                      context,
                      medicine: medicine,
                    );
                    if (res == true) {
                      ref.read(medicinesNotifierProvider.notifier).loadAll();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_2, color: Colors.teal, size: 20),
                  tooltip: 'طباعة الباركود',
                  onPressed: () => _showBarcodeDialog(context, medicine),
                ),
                IconButton(
                  icon: const Icon(Icons.layers, color: Colors.deepPurple, size: 20),
                  tooltip: 'إعداد مستويات التعبئة',
                  onPressed: () => showUnitHierarchyDialog(
                    context,
                    medicine: medicine,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'حذف / أرشفة',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('تأكيد الأرشفة'),
                        content: Text('هل أنت متأكد من أرشفة ${medicine.nameAr}؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('أرشفة'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(medicinesNotifierProvider.notifier).deleteMedicine(medicine.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(medicinesNotifierProvider);

    var displayedItems = state.items;
    if (_activeFilter == MedicinesFilter.cosmeticsAndDiapers) {
      displayedItems = displayedItems.where((m) => m.medicineType == 4 || m.medicineType == 5).toList();
    } else if (_activeFilter == MedicinesFilter.incomplete) {
      displayedItems = displayedItems.where((m) =>
          (m.nameEn == null || m.nameEn!.isEmpty) ||
          (m.nameScientific == null || m.nameScientific!.isEmpty) ||
          (m.companyName == null || m.companyName!.isEmpty) ||
          (m.supplierName == null || m.supplierName!.isEmpty) ||
          m.medicineType == 0).toList();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('دليل أدوية السوق اليمني (قائمة الأدوية الشاملة)'),
          actions: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('استيراد من Excel/CSV'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicineImportScreen()),
                ).then((_) => ref.read(medicinesNotifierProvider.notifier).loadAll());
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث القائمة',
              onPressed: () => ref.read(medicinesNotifierProvider.notifier).loadAll(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // شريط البحث والفلترة العلوية
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Colors.blue),
                            hintText: 'ابحث بالاسم العربي، الإنجليزي، العلمي، رقم الدواء، أو الباركود...',
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(medicinesNotifierProvider.notifier).search('');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          onChanged: (val) => ref.read(medicinesNotifierProvider.notifier).search(val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة دواء جديد'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MedicineFormScreen()),
                        ).then((_) => ref.read(medicinesNotifierProvider.notifier).loadAll()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // أزرار الفلترة السريعة
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('كافة الأدوية'),
                        selected: _activeFilter == MedicinesFilter.all,
                        onSelected: (val) => setState(() => _activeFilter = MedicinesFilter.all),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('مستحضرات التجميل والحفاضات'),
                        selected: _activeFilter == MedicinesFilter.cosmeticsAndDiapers,
                        onSelected: (val) => setState(() => _activeFilter = MedicinesFilter.cosmeticsAndDiapers),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                        label: const Text('نواقص البيانات (حقول فارغة تحتاج استكمال)'),
                        selected: _activeFilter == MedicinesFilter.incomplete,
                        onSelected: (val) => setState(() => _activeFilter = MedicinesFilter.incomplete),
                      ),
                      const Spacer(),
                      Text(
                        'إجمالي المعروض: ${displayedItems.length} صنف',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cleaning_services, color: Colors.orange),
                        label: const Text('تنظيف التكرارات (دمج)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                        onPressed: () {
                          RoleGuard.checkPermission(
                            context: context,
                            ref: ref,
                            permission: AppPermission.manageUsers, // Assuming owner/manager role has manageUsers or similar high-level permission.
                            onGranted: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('تنظيف التكرارات'),
                                  content: const Text('سيتم البحث عن الأدوية ذات الأسماء المتطابقة ودمجها مع نقل أرصدتها، وحذف التكرارات. هل تريد الاستمرار؟'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('موافق')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final mergedCount = await ref.read(medicinesNotifierProvider.notifier).autoCleanDuplicates();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('اكتملت العملية. تم دمج وحذف $mergedCount سجل مكرر.')),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // جدول البيانات القابل للتمرير الأفقي والرأسي
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(state.errorMessage!, style: const TextStyle(fontSize: 16, color: Colors.red)),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                                onPressed: () => ref.read(medicinesNotifierProvider.notifier).loadAll(),
                              ),
                            ],
                          ),
                        )
                      : displayedItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  const Text('لا توجد أدوية مطابقة للبحث', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('إضافة هذا الدواء كصنف جديد'),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const MedicineFormScreen()),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            trackVisibility: true,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 1760,
                                child: Column(
                                  children: [
                                    _buildTableHeader(),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: displayedItems.length,
                                        itemBuilder: (context, index) {
                                          return _buildTableRow(context, ref, displayedItems[index], index);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
