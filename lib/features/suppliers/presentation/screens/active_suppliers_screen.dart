// شاشة "الموردين المتعامل معهم" - PharmaOS
// تبدأ فارغة تماماً، ويتولى صاحب الصيدلية استيراد من يتعامل معهم من الدليل العام أو إضافة موردين مخصصين

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/suppliers_provider.dart';
import '../providers/pharmacy_debts_provider.dart';
import '../../domain/entities/suppliers_entity.dart';
import 'supplier_ledger_screen.dart';
import '../../../../core/services/medicine_translation_service.dart';
import '../../../../core/services/partnered_entities_service.dart';

class ActiveSuppliersScreen extends ConsumerStatefulWidget {
  const ActiveSuppliersScreen({super.key});

  @override
  ConsumerState<ActiveSuppliersScreen> createState() => _ActiveSuppliersScreenState();
}

class _ActiveSuppliersScreenState extends ConsumerState<ActiveSuppliersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<int> _partneredIds = [];
  bool _isLoadingPartnered = true;

  @override
  void initState() {
    super.initState();
    _loadPartneredIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPartneredIds() async {
    setState(() => _isLoadingPartnered = true);
    final ids = await PartneredEntitiesService.getPartneredSupplierIds();
    if (mounted) {
      setState(() {
        _partneredIds = ids;
        _isLoadingPartnered = false;
      });
    }
  }

  Future<void> _togglePartner(SupplierEntity supplier) async {
    if (_partneredIds.contains(supplier.id)) {
      await PartneredEntitiesService.removePartneredSupplier(supplier.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إزالة "${supplier.name}" من قائمة التعامل')),
      );
    } else {
      await PartneredEntitiesService.addPartneredSupplier(supplier.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إضافة "${supplier.name}" إلى قائمة الموردين المتعامل معهم ✓'), backgroundColor: Colors.green),
      );
    }
    await _loadPartneredIds();
  }

  void _showImportFromGeneralCatalogDialog(BuildContext context, List<SupplierEntity> allSuppliers) {
    final catalogSearchController = TextEditingController();
    String catalogQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = catalogQuery.trim().toLowerCase();
          final filtered = allSuppliers.where((s) {
            final name = s.name.toLowerCase();
            final trans = MedicineTranslationService.translate(s.name).toLowerCase();
            return name.contains(q) || trans.contains(q) || s.id.toString().contains(q);
          }).toList();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.playlist_add_check, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text('اختيار من دليل الموردين العام (${allSuppliers.length} مورد)'),
                ],
              ),
              content: SizedBox(
                width: 550,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      controller: catalogSearchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.teal),
                        hintText: 'ابحث باسم المورد أو الوكالة أو الشركة...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                      onChanged: (val) => setDialogState(() => catalogQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('لا توجد نتائج'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final s = filtered[index];
                                final isAlreadyPartner = _partneredIds.contains(s.id);
                                final trans = MedicineTranslationService.translate(s.name);
                                final hasTrans = trans.isNotEmpty && trans != s.name;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: isAlreadyPartner ? Colors.teal.shade50 : Colors.white,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isAlreadyPartner ? Colors.teal : Colors.grey.shade200,
                                      child: Icon(
                                        isAlreadyPartner ? Icons.check : Icons.business,
                                        color: isAlreadyPartner ? Colors.white : Colors.blueGrey,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: hasTrans ? Text(trans, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)) : null,
                                    trailing: isAlreadyPartner
                                        ? const Chip(label: Text('مضاف للتعامل', style: TextStyle(fontSize: 11, color: Colors.teal)))
                                        : FilledButton.tonal(
                                            child: const Text('إضافة للتعامل'),
                                            onPressed: () async {
                                              await _togglePartner(s);
                                              setDialogState(() {});
                                            },
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
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddCustomPartnerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.teal),
              SizedBox(width: 8),
              Text('إضافة مورد متعامل معه جديد'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'اسم المورد / الوكيل (إلزامي)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف / مسؤول المبيعات', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات / شروط السداد', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final ok = await ref.read(suppliersNotifierProvider.notifier).add(
                      name: name,
                      contactInfo: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    );
                if (ok && mounted) {
                  Navigator.pop(ctx);
                  await ref.read(suppliersNotifierProvider.notifier).loadAll();
                  final all = ref.read(suppliersNotifierProvider).items;
                  final created = all.where((s) => s.name == name).firstOrNull;
                  if (created != null) {
                    await _togglePartner(created);
                  }
                }
              },
              child: const Text('حفظ وإضافة لقائمة التعامل'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliersState = ref.watch(suppliersNotifierProvider);
    final debtsState = ref.watch(pharmacyDebtsNotifierProvider);

    // فلترة الموردين المتعامل معهم فقط
    final partneredSuppliers = suppliersState.items.where((s) => _partneredIds.contains(s.id)).toList();

    final q = _searchQuery.trim().toLowerCase();
    final filtered = partneredSuppliers.where((s) {
      final name = s.name.toLowerCase();
      final trans = MedicineTranslationService.translate(s.name).toLowerCase();
      final phone = (s.contactInfo ?? '').toLowerCase();
      return name.contains(q) || trans.contains(q) || phone.contains(q) || s.id.toString().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('الموردون المتعامل معهم (${partneredSuppliers.length})'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () {
                _loadPartneredIds();
                ref.read(suppliersNotifierProvider.notifier).loadAll();
                ref.read(pharmacyDebtsNotifierProvider.notifier).loadDebts();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // شريط الإجراءات والبحث
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
                            prefixIcon: const Icon(Icons.search, color: Colors.teal),
                            hintText: 'ابحث في الموردين المتعامل معهم بالعربي أو الإنجليزي أو الهاتف...',
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
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('استيراد من الدليل العام'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showImportFromGeneralCatalogDialog(context, suppliersState.items),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('إضافة مورد مخصص'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showAddCustomPartnerDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // قائمة الموردين المتعامل معهم
            Expanded(
              child: _isLoadingPartnered || suppliersState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : partneredSuppliers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.handshake_outlined, size: 72, color: Colors.teal.shade300),
                              const SizedBox(height: 14),
                              const Text(
                                'قائمة الموردين المتعامل معهم فارغة حالياً ✓',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'اضغط على "استيراد من الدليل العام" لاختيار الموردين الذين تتعامل معهم صيدليتك، أو أضف مورداً مخصصاً جديداً.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(Icons.playlist_add),
                                label: const Text('استعراض واختيار الموردين من الدليل'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                                onPressed: () => _showImportFromGeneralCatalogDialog(context, suppliersState.items),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? const Center(child: Text('لا يوجد موردون مطابقون للبحث'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final supplier = filtered[index];
                                final debtRecord = debtsState.items.where((d) => d.supplierId == supplier.id).firstOrNull;
                                final debtAmount = debtRecord?.remainingDebt ?? 0.0;
                                final hasDebt = debtAmount > 0;

                                final translated = MedicineTranslationService.translate(supplier.name);
                                final hasTrans = translated.isNotEmpty && translated != supplier.name;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 1,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: hasDebt ? Colors.red.shade50 : Colors.teal.shade50,
                                      child: Icon(
                                        Icons.business,
                                        color: hasDebt ? Colors.red : Colors.teal,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          supplier.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        if (hasTrans) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              translated,
                                              style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Text(
                                            'دين الصيدلية: ${debtAmount.toStringAsFixed(0)} ر.ي',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: hasDebt ? Colors.red : Colors.green,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Text(
                                            'الهاتف: ${supplier.contactInfo ?? "غير محدد"}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.receipt_long, size: 16),
                                          label: const Text('كشف الحساب'),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SupplierLedgerScreen(supplier: supplier),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                          tooltip: 'إزالة من قائمة التعامل',
                                          onPressed: () => _togglePartner(supplier),
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
