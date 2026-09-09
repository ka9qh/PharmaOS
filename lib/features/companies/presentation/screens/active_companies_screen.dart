// شاشة "الشركات المتعامل معهم" - PharmaOS
// تبدأ فارغة تماماً، ويقوم صاحب الصيدلية باختيار الشركات المصنعة التي يتعامل معها
// من الدليل العام (2,157 شركة) أو إضافة شركات ومصانع جديدة.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/companies_provider.dart';
import '../../domain/entities/companies_entity.dart';
import '../../../../core/services/medicine_translation_service.dart';
import '../../../../core/services/partnered_entities_service.dart';
import '../../../medicines/presentation/screens/medicines_screen.dart';

class ActiveCompaniesScreen extends ConsumerStatefulWidget {
  const ActiveCompaniesScreen({super.key});

  @override
  ConsumerState<ActiveCompaniesScreen> createState() => _ActiveCompaniesScreenState();
}

class _ActiveCompaniesScreenState extends ConsumerState<ActiveCompaniesScreen> {
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
    final ids = await PartneredEntitiesService.getPartneredCompanyIds();
    if (mounted) {
      setState(() {
        _partneredIds = ids;
        _isLoadingPartnered = false;
      });
    }
  }

  Future<void> _togglePartner(CompanyEntity company) async {
    if (_partneredIds.contains(company.id)) {
      await PartneredEntitiesService.removePartneredCompany(company.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إزالة شركة "${company.name}" من قائمة التعامل')),
      );
    } else {
      await PartneredEntitiesService.addPartneredCompany(company.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إضافة شركة "${company.name}" إلى قائمة الشركات المتعامل معها ✓'), backgroundColor: Colors.green),
      );
    }
    await _loadPartneredIds();
  }

  void _showImportFromGeneralCatalogDialog(BuildContext context, List<CompanyEntity> allCompanies) {
    final catalogSearchController = TextEditingController();
    String catalogQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = catalogQuery.trim().toLowerCase();
          final filtered = allCompanies.where((c) {
            final name = c.name.toLowerCase();
            final trans = MedicineTranslationService.translate(c.name).toLowerCase();
            return name.contains(q) || trans.contains(q) || c.id.toString().contains(q);
          }).toList();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.factory_outlined, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text('اختيار من دليل الشركات العام (${allCompanies.length} شركة)'),
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
                        prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                        hintText: 'ابحث باسم الشركة بالعربي أو الإنجليزي...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                      onChanged: (val) => setDialogState(() => catalogQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('لا توجد نتائج مطابقة'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final c = filtered[index];
                                final isAlreadyPartner = _partneredIds.contains(c.id);
                                final trans = MedicineTranslationService.translate(c.name);
                                final hasTrans = trans.isNotEmpty && trans != c.name;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: isAlreadyPartner ? Colors.indigo.shade50 : Colors.white,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isAlreadyPartner ? Colors.indigo : Colors.grey.shade200,
                                      child: Icon(
                                        isAlreadyPartner ? Icons.check : Icons.business,
                                        color: isAlreadyPartner ? Colors.white : Colors.blueGrey,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: hasTrans ? Text(trans, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)) : null,
                                    trailing: isAlreadyPartner
                                        ? const Chip(label: Text('مضافة للتعامل', style: TextStyle(fontSize: 11, color: Colors.indigo)))
                                        : FilledButton.tonal(
                                            child: const Text('إضافة للتعامل'),
                                            onPressed: () async {
                                              await _togglePartner(c);
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

  void _showAddCustomCompanyDialog(BuildContext context) {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_business, color: Colors.indigo),
              SizedBox(width: 8),
              Text('إضافة شركة مصنعة جديدة'),
            ],
          ),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم الشركة (عربي أو إنجليزي)', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final ok = await ref.read(companiesNotifierProvider.notifier).add(name);
                if (ok && mounted) {
                  Navigator.pop(ctx);
                  await ref.read(companiesNotifierProvider.notifier).loadAll();
                  final all = ref.read(companiesNotifierProvider).items;
                  final created = all.where((c) => c.name == name).firstOrNull;
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
    final companiesState = ref.watch(companiesNotifierProvider);

    // تصفية الشركات المتعامل معها فقط
    final partneredCompanies = companiesState.items.where((c) => _partneredIds.contains(c.id)).toList();

    final q = _searchQuery.trim().toLowerCase();
    final filtered = partneredCompanies.where((c) {
      final name = c.name.toLowerCase();
      final trans = MedicineTranslationService.translate(c.name).toLowerCase();
      return name.contains(q) || trans.contains(q) || c.id.toString().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('الشركات المتعامل معها (${partneredCompanies.length})'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () {
                _loadPartneredIds();
                ref.read(companiesNotifierProvider.notifier).loadAll();
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                        hintText: 'ابحث في الشركات المتعامل معها بالعربي أو الإنجليزي...',
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
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showImportFromGeneralCatalogDialog(context, companiesState.items),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('إضافة شركة مخصصة'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showAddCustomCompanyDialog(context),
                  ),
                ],
              ),
            ),

            // قائمة الشركات
            Expanded(
              child: _isLoadingPartnered || companiesState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : partneredCompanies.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business_center_outlined, size: 72, color: Colors.indigo.shade300),
                              const SizedBox(height: 14),
                              const Text(
                                'قائمة الشركات المتعامل معها فارغة حالياً ✓',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'اضغط على "استيراد من الدليل العام" لاختيار الشركات والمصانع التي توفر أدويتها بصيدليتك.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(Icons.playlist_add),
                                label: const Text('استعراض واختيار الشركات من الدليل'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                                onPressed: () => _showImportFromGeneralCatalogDialog(context, companiesState.items),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? const Center(child: Text('لا توجد شركات مطابقة للبحث'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final company = filtered[index];
                                final translated = MedicineTranslationService.translate(company.name);
                                final hasTrans = translated.isNotEmpty && translated != company.name;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 1,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.indigo.shade50,
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade800, fontSize: 13),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          company.name,
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
                                    subtitle: Text('رقم المعرف: #${company.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.medication_outlined, size: 16),
                                          label: const Text('أدوية الشركة'),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const MedicinesScreen()),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                          tooltip: 'إزالة من قائمة التعامل',
                                          onPressed: () => _togglePartner(company),
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
