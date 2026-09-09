// شاشة إدارة التصنيفات والأقسام الدوائية (عربي + إنجليزي) مع البحث الفوري

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/categories_provider.dart';
import '../../../../core/services/medicine_translation_service.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoriesNotifierProvider);

    ref.listen<CategoriesState>(categoriesNotifierProvider, (previous, next) {
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
    final filteredCategories = state.items.where((c) {
      final name = c.name.toLowerCase();
      final trans = c.nameEn?.toLowerCase() ?? '';
      return name.contains(q) || trans.contains(q) || c.id.toString().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('الأقسام والتصنيفات العلاجية (${state.items.length})'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () => ref.read(categoriesNotifierProvider.notifier).loadAll(),
            ),
          ],
        ),
        body: Column(
          children: [
            // شريط البحث
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
                        hintText: 'ابحث بالتصنيف بالعربي أو الإنجليزي...',
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
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة تصنيف'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showAddDialog(context, ref),
                  ),
                ],
              ),
            ),

            // قائمة التصنيفات كجدول
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredCategories.isEmpty
                      ? const Center(child: Text('لا توجد تصنيفات مطابقة للبحث', style: TextStyle(fontSize: 16, color: Colors.grey)))
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
                                        itemCount: filteredCategories.length,
                                        itemBuilder: (context, index) {
                                          return _buildTableRow(context, ref, filteredCategories[index], index);
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
          SizedBox(width: 300, child: Text('اسم التصنيف (عربي)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 300, child: Text('الاسم بالإنجليزي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          Expanded(child: Text('الإجراءات', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, WidgetRef ref, dynamic category, int index) {
    final isEven = index % 2 == 0;
    final displayEn = (category.nameEn != null && category.nameEn!.isNotEmpty) ? category.nameEn! : '-';

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
            child: Text('${category.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          SizedBox(
            width: 300,
            child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                  tooltip: 'تعديل اسم التصنيف',
                  onPressed: () => _showEditDialog(context, ref, category.id, category.name),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'أرشفة / حذف',
                  onPressed: () => _showDeleteConfirmDialog(context, ref, category.id, category.name),
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
          title: const Text('إضافة تصنيف علاجي جديد'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'اسم التصنيف (عربي أو إنجليزي)', border: OutlineInputBorder()),
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
                final success = await ref.read(categoriesNotifierProvider.notifier).add(controller.text.trim());
                if (success && context.mounted) Navigator.pop(context);
              },
              child: const Text('حفظ التصنيف'),
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
          title: const Text('تعديل اسم التصنيف'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'اسم التصنيف', border: OutlineInputBorder()),
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
                final success = await ref.read(categoriesNotifierProvider.notifier).updateCategory(id, controller.text.trim());
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
          content: Text('هل أنت متأكد من رغبتك في أرشفة التصنيف "$name"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final success = await ref.read(categoriesNotifierProvider.notifier).deleteCategory(id);
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
