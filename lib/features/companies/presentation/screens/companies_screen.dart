// شاشة إدارة شركات الأدوية (عربي + إنجليزي) مع البحث الفوري والترقيم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/companies_provider.dart';
import '../../../../core/services/medicine_translation_service.dart';

class CompaniesScreen extends ConsumerStatefulWidget {
  const CompaniesScreen({super.key});

  @override
  ConsumerState<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends ConsumerState<CompaniesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companiesNotifierProvider);

    ref.listen<CompaniesState>(companiesNotifierProvider, (previous, next) {
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.successMessage!),
          backgroundColor: Colors.green,
        ));
      }
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.errorMessage!),
          backgroundColor: Colors.red,
        ));
      }
    });

    final q = _searchQuery.trim().toLowerCase();
    final filteredCompanies = state.items.where((c) {
      final name = c.name.toLowerCase();
      final trans = c.nameEn?.toLowerCase() ?? '';
      return name.contains(q) || trans.contains(q) || c.id.toString().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('دليل الشركات المصنعة (${state.items.length} شركة)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () => ref.read(companiesNotifierProvider.notifier).loadAll(),
            ),
          ],
        ),
        body: Column(
          children: [
            // شريط البحث والتحكم
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.blue),
                        hintText: 'ابحث باسم الشركة بالعربي أو الإنجليزي أو الرقم...',
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
                    icon: const Icon(Icons.add_business),
                    label: const Text('إضافة شركة'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showAddDialog(context, ref),
                  ),
                ],
              ),
            ),

            // قائمة الشركات كجدول
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredCompanies.isEmpty
                      ? const Center(child: Text('لا توجد شركات مطابقة للبحث', style: TextStyle(fontSize: 16, color: Colors.grey)))
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
                                width: 900,
                                child: Column(
                                  children: [
                                    _buildTableHeader(),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: filteredCompanies.length,
                                        itemBuilder: (context, index) {
                                          return _buildTableRow(context, ref, filteredCompanies[index], index);
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

  Widget _buildTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: const Row(
        children: [
          SizedBox(width: 80, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 300, child: Text('اسم الشركة (عربي)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 300, child: Text('الاسم بالإنجليزي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          Expanded(child: Text('الإجراءات', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, WidgetRef ref, dynamic company, int index) {
    final isEven = index % 2 == 0;
    final displayEn = (company.nameEn != null && company.nameEn!.isNotEmpty) ? company.nameEn! : '-';

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('${company.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          SizedBox(
            width: 300,
            child: Text(company.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          SizedBox(
            width: 300,
            child: Text(displayEn, style: const TextStyle(fontSize: 14, color: Colors.teal)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  tooltip: 'تعديل اسم الشركة',
                  onPressed: () => _showEditDialog(context, ref, company.id, company.name),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'أرشفة / حذف',
                  onPressed: () => _showDeleteConfirmDialog(context, ref, company.id, company.name),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_business, color: Colors.blue),
              SizedBox(width: 8),
              Text('إضافة شركة جديدة'),
            ],
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'اسم الشركة (عربي أو إنجليزي)',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                final success = await ref.read(companiesNotifierProvider.notifier).add(controller.text.trim());
                if (success && context.mounted) Navigator.pop(context);
              },
              child: const Text('حفظ الشركة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, int id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل اسم الشركة'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'اسم الشركة', border: OutlineInputBorder()),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                final success = await ref.read(companiesNotifierProvider.notifier).updateCompany(id, controller.text.trim());
                if (success && context.mounted) Navigator.pop(context);
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف / أرشفة الشركة "$name"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final success = await ref.read(companiesNotifierProvider.notifier).deleteCompany(id);
                if (success && context.mounted) Navigator.pop(context);
              },
              child: const Text('تأكيد الحذف'),
            ),
          ],
        ),
      ),
    );
  }
}
