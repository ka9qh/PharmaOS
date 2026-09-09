// مكون نافذة الاختيار والبحث الفوري العام - PharmaOS
// يتيح البحث الفوري واختيار المورد، الشركة، أو الدواء مع إعطاء الأولوية لقوائم التعامل

import 'package:flutter/material.dart';
import '../../features/suppliers/domain/entities/suppliers_entity.dart';
import '../../features/companies/domain/entities/companies_entity.dart';
import '../services/medicine_translation_service.dart';
import '../services/partnered_entities_service.dart';

class SearchableSupplierPicker {
  static Future<SupplierEntity?> show(
    BuildContext context, {
    required List<SupplierEntity> allSuppliers,
    int? currentSelectedId,
    required Future<void> Function(String name, String? phone) onAddNewSupplier,
  }) async {
    final partneredIds = await PartneredEntitiesService.getPartneredSupplierIds();
    final searchController = TextEditingController();
    String searchQuery = '';
    int activeTab = partneredIds.isNotEmpty ? 0 : 1; // 0: المتعامل معهم, 1: الدليل العام

    return showDialog<SupplierEntity>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final partneredList = allSuppliers.where((s) => partneredIds.contains(s.id)).toList();
          final targetList = activeTab == 0 ? (partneredList.isNotEmpty ? partneredList : allSuppliers) : allSuppliers;

          final q = searchQuery.trim().toLowerCase();
          final filtered = targetList.where((s) {
            final name = s.name.toLowerCase();
            final trans = MedicineTranslationService.translate(s.name).toLowerCase();
            final phone = (s.contactInfo ?? '').toLowerCase();
            return name.contains(q) || trans.contains(q) || phone.contains(q) || s.id.toString().contains(q);
          }).toList();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.person_search_outlined, color: Colors.teal),
                  const SizedBox(width: 8),
                  const Text('اختيار المورد / الوكيل'),
                ],
              ),
              content: SizedBox(
                width: 550,
                height: 500,
                child: Column(
                  children: [
                    // تبويبات الموردين
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text('الموردون المتعامل معهم (${partneredList.length})'),
                            selected: activeTab == 0,
                            onSelected: (_) => setDialogState(() => activeTab = 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Text('الدليل العام (${allSuppliers.length})'),
                            selected: activeTab == 1,
                            onSelected: (_) => setDialogState(() => activeTab = 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // شريط البحث
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.teal),
                        hintText: 'ابحث باسم المورد بالعربي أو الإنجليزي أو الهاتف...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),

                    // قائمة الموردين
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('لا توجد نتائج مطابقة للبحث'),
                                  const SizedBox(height: 8),
                                  if (activeTab == 0 && partneredList.isEmpty)
                                    TextButton.icon(
                                      icon: const Icon(Icons.search),
                                      label: const Text('البحث في الدليل العام للموردين'),
                                      onPressed: () => setDialogState(() => activeTab = 1),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final s = filtered[index];
                                final isSelected = s.id == currentSelectedId;
                                final isPartner = partneredIds.contains(s.id);
                                final trans = MedicineTranslationService.translate(s.name);
                                final hasTrans = trans.isNotEmpty && trans != s.name;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: isSelected ? Colors.teal.shade50 : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: isSelected ? Colors.teal : Colors.grey.shade200),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isPartner ? Colors.teal.shade50 : Colors.grey.shade100,
                                      child: Text('${index + 1}', style: TextStyle(color: isPartner ? Colors.teal : Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      '${hasTrans ? "$trans | " : ""}الهاتف: ${s.contactInfo ?? "غير محدد"}',
                                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                    ),
                                    trailing: FilledButton.tonal(
                                      child: const Text('اختيار'),
                                      onPressed: () => Navigator.pop(ctx, s),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('إضافة مورد جديد فوراً'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final nameCtrl = TextEditingController();
                    final phoneCtrl = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (addCtx) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('إضافة مورد جديد'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المورد *', border: OutlineInputBorder())),
                              const SizedBox(height: 12),
                              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(addCtx), child: const Text('إلغاء')),
                            FilledButton(
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) return;
                                await onAddNewSupplier(name, phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim());
                                if (context.mounted) Navigator.pop(addCtx);
                              },
                              child: const Text('حفظ واختيار'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<T?> showSearchableEntityPicker<T>({
  required BuildContext context,
  required List<T> items,
  required String title,
  required String searchHint,
  required String Function(T) itemLabelBuilder,
  required bool Function(T, String) searchFilter,
}) async {
  String searchQuery = '';
  return showDialog<T>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final filtered = items.where((i) => searchFilter(i, searchQuery)).toList();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.search, color: Colors.teal),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: SizedBox(
              width: 550,
              height: 500,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      hintText: searchHint,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    onChanged: (val) => setDialogState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('لا توجد نتائج مطابقة للبحث'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.teal.shade50,
                                    child: Text('${index + 1}', style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(itemLabelBuilder(item), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: FilledButton.tonal(
                                    child: const Text('اختيار'),
                                    onPressed: () => Navigator.pop(ctx, item),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
