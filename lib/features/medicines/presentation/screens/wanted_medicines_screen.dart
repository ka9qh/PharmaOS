// شاشة النواقص والأدوية المطلوبة للعملاء وتنبيهات الطلب الذكية - PharmaOS
// تتيح تسجيل الأدوية التي يطلبها العملاء وغير متوفرة، وحساب عداد الطلبات،
// والربط التلقائي بالمورد المسؤول وطلبه عبر واتساب بلمسة واحدة.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/services/wanted_medicines_service.dart';
import '../../../../core/services/supplier_catalog_mapping_service.dart';
import '../../../suppliers/presentation/screens/medicine_supplier_finder_screen.dart';
import '../../domain/entities/medicines_entity.dart';
import '../providers/medicines_provider.dart';

class WantedMedicinesScreen extends ConsumerStatefulWidget {
  const WantedMedicinesScreen({super.key});

  @override
  ConsumerState<WantedMedicinesScreen> createState() => _WantedMedicinesScreenState();
}

class _WantedMedicinesScreenState extends ConsumerState<WantedMedicinesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, pending, ordered, fulfilled
  List<WantedMedicineItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final list = await WantedMedicinesService.getWantedItems();
    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  void _showAddDemandDialog() {
    final medNameCtrl = TextEditingController();
    final customerNameCtrl = TextEditingController();
    final customerPhoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    MedicineEntity? selectedCatalogMed;

    final allMedicines = ref.read(medicinesNotifierProvider).items;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_alert_outlined, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text('تسجيل طلب دواء ناقص من عميل'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اسم الدواء المطلوب *', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Autocomplete<MedicineEntity>(
                      displayStringForOption: (m) => '${m.nameAr} (${m.companyName ?? "عام"})',
                      optionsBuilder: (textVal) {
                        if (textVal.text.isEmpty) return const [];
                        final q = textVal.text.toLowerCase();
                        return allMedicines.where((m) {
                          return m.nameAr.toLowerCase().contains(q) || (m.nameEn != null && m.nameEn!.toLowerCase().contains(q));
                        }).take(10);
                      },
                      onSelected: (m) {
                        setDialogState(() {
                          selectedCatalogMed = m;
                          medNameCtrl.text = m.nameAr;
                        });
                      },
                      fieldViewBuilder: (ctx, textEditingController, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'اكتب اسم الدواء أو اختر من الكتالوج...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.medication, color: Colors.teal),
                          ),
                          onChanged: (val) {
                            medNameCtrl.text = val;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customerNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم العميل (اختياري)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customerPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم هاتف العميل للتواصل معه عند التوفر (اختياري)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات / الجرعة المطلوبة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('تسجيل في النواقص'),
                style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                onPressed: () async {
                  final name = medNameCtrl.text.trim();
                  if (name.isEmpty) return;

                  await WantedMedicinesService.recordDemand(
                    medicineName: name,
                    medicineId: selectedCatalogMed?.id,
                    companyName: selectedCatalogMed?.companyName,
                    customerName: customerNameCtrl.text.trim().isEmpty ? null : customerNameCtrl.text.trim(),
                    customerPhone: customerPhoneCtrl.text.trim().isEmpty ? null : customerPhoneCtrl.text.trim(),
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );

                  await _loadItems();
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم تسجيل طلب الدواء "$name" بنجاح وتم تحديث عداد الطلب ✓'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _items.where((i) {
      final matchQ = i.medicineName.toLowerCase().contains(q) ||
          (i.companyName ?? '').toLowerCase().contains(q) ||
          i.requestingCustomerNames.any((n) => n.toLowerCase().contains(q));

      final matchStatus = _statusFilter == 'all' || i.status == _statusFilter;
      return matchQ && matchStatus;
    }).toList();

    final highDemandCount = _items.where((i) => i.status == 'pending' && i.demandCount >= 2).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('النواقص وطلبات العملاء المتكررة (${_items.length})'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: _loadItems,
            ),
          ],
        ),
        body: Column(
          children: [
            // بطاقة التنبيهات وشريط البحث
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (highDemandCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.red, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'تنبيه ذكي: يوجد $highDemandCount صنف دوائي عليه طلب متكرر من عدة عملاء ولم يتم توفيره بعد!',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Colors.deepOrange),
                            hintText: 'ابحث في النواقص باسم الدواء أو العميل أو الشركة...',
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_alert),
                        label: const Text('تسجيل طلب ناقص جديد'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showAddDemandDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // فلاتر الحالة
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text('الكل (${_items.length})'),
                        selected: _statusFilter == 'all',
                        onSelected: (_) => setState(() => _statusFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('قيد الطلب والنواقص (${_items.where((i) => i.status == "pending").length})'),
                        selected: _statusFilter == 'pending',
                        onSelected: (_) => setState(() => _statusFilter = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('تم طلبه من المورد (${_items.where((i) => i.status == "ordered").length})'),
                        selected: _statusFilter == 'ordered',
                        onSelected: (_) => setState(() => _statusFilter = 'ordered'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('تم التوفير بالصيدلية (${_items.where((i) => i.status == "fulfilled").length})'),
                        selected: _statusFilter == 'fulfilled',
                        onSelected: (_) => setState(() => _statusFilter = 'fulfilled'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // قائمة النواقص
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade400),
                              const SizedBox(height: 14),
                              const Text(
                                'لا توجد أدوية مطلوبة أو نواقص مسجلة حالياً ✓',
                                style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isHighDemand = item.demandCount >= 2;

                            Color statusColor;
                            String statusText;
                            if (item.status == 'fulfilled') {
                              statusColor = Colors.green;
                              statusText = 'تم التوفير ✓';
                            } else if (item.status == 'ordered') {
                              statusColor = Colors.blue;
                              statusText = 'تم طلبه من المورد';
                            } else {
                              statusColor = isHighDemand ? Colors.red : Colors.orange;
                              statusText = 'ناقص / قيد الانتظار';
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: isHighDemand ? Colors.red.shade200 : Colors.transparent),
                              ),
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: isHighDemand ? Colors.red.shade50 : Colors.orange.shade50,
                                          child: Icon(
                                            isHighDemand ? Icons.local_fire_department : Icons.pending_actions,
                                            color: isHighDemand ? Colors.red : Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    item.medicineName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isHighDemand ? Colors.red : Colors.blueGrey.shade100,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'طلب ${item.demandCount} مرات ${isHighDemand ? "🔥" : ""}',
                                                      style: TextStyle(
                                                        color: isHighDemand ? Colors.white : Colors.blueGrey.shade900,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: statusColor.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      statusText,
                                                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'الشركة: ${item.companyName ?? "غير محدد"} | آخر طلب: ${DateFormat("yyyy-MM-dd HH:mm").format(item.lastRequestedAt)}',
                                                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                              ),
                                              if (item.requestingCustomerNames.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'العملاء الطالبين: ${item.requestingCustomerNames.join("، ")}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // زر زيادة العداد عند طلب عميل جديد
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('+1 طلب عميل جديد'),
                                          onPressed: () async {
                                            await WantedMedicinesService.recordDemand(medicineName: item.medicineName);
                                            await _loadItems();
                                          },
                                        ),
                                        Row(
                                          children: [
                                            // زر كشف المورد ومراسلته
                                            FilledButton.icon(
                                              icon: const Icon(Icons.person_search_outlined, size: 16),
                                              label: const Text('كشف المورد والطلب'),
                                              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => MedicineSupplierFinderScreen(
                                                      initialMedicine: MedicineEntity(
                                                        id: item.medicineId ?? 0,
                                                        nameAr: item.medicineName,
                                                        companyName: item.companyName,
                                                        sku: '',
                                                        barcode: '',
                                                        unit: 'باكت',
                                                        purchasePrice: 0,
                                                        sellingPrice: 0,
                                                        reorderLevel: 0,
                                                        isActive: true,
                                                        medicineType: 1,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),

                                            // تبديل الحالة
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert),
                                              onSelected: (newStatus) async {
                                                if (newStatus == 'delete') {
                                                  await WantedMedicinesService.deleteItem(item.id);
                                                } else {
                                                  await WantedMedicinesService.updateStatus(item.id, newStatus);
                                                }
                                                await _loadItems();
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(value: 'pending', child: Text('تعيين كـ قيد البحث')),
                                                const PopupMenuItem(value: 'ordered', child: Text('تعيين كـ تم الطلب من المورد')),
                                                const PopupMenuItem(value: 'fulfilled', child: Text('تعيين كـ تم التوفير بنجاح ✓')),
                                                const PopupMenuDivider(),
                                                const PopupMenuItem(value: 'delete', child: Text('حذف من القائمة', style: TextStyle(color: Colors.red))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
