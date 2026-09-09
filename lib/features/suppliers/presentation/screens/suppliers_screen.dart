// شاشة دليل الموردين والوكالات (عربي + إنجليزي) مع شريط البحث والترقيم

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/suppliers_provider.dart';
import 'supplier_profile_screen.dart';
import '../../../../core/services/medicine_translation_service.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(suppliersNotifierProvider);

    ref.listen<SuppliersState>(suppliersNotifierProvider, (previous, next) {
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
    final filteredSuppliers = state.items.where((s) {
      final name = s.name.toLowerCase();
      final trans = s.nameEn?.toLowerCase() ?? '';
      final contact = (s.contactInfo ?? '').toLowerCase();
      return name.contains(q) || trans.contains(q) || contact.contains(q) || s.id.toString().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('دليل الموردين والوكالات (${state.items.length} مورد)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () => ref.read(suppliersNotifierProvider.notifier).loadAll(),
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
                        hintText: 'ابحث باسم المورد/الوكيل بالعربي أو الإنجليزي أو الهاتف أو الرقم...',
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
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('إضافة مورد'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showAddDialog(context, ref),
                  ),
                ],
              ),
            ),

            // قائمة الموردين كجدول
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredSuppliers.isEmpty
                      ? const Center(child: Text('لا يوجد موردون مطابقون للبحث', style: TextStyle(fontSize: 16, color: Colors.grey)))
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
                                width: 950,
                                child: Column(
                                  children: [
                                    _buildTableHeader(),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: filteredSuppliers.length,
                                        itemBuilder: (context, index) {
                                          return _buildTableRow(context, ref, filteredSuppliers[index], index);
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
          SizedBox(width: 250, child: Text('اسم المورد (عربي)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 250, child: Text('الاسم بالإنجليزي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 150, child: Text('الهاتف / وسيلة التواصل', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          Expanded(child: Text('الإجراءات', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, WidgetRef ref, dynamic supplier, int index) {
    final isEven = index % 2 == 0;
    final displayEn = (supplier.nameEn != null && supplier.nameEn!.isNotEmpty) ? supplier.nameEn! : '-';

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
            child: Text('${supplier.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          SizedBox(
            width: 250,
            child: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          SizedBox(
            width: 250,
            child: Text(displayEn, style: const TextStyle(fontSize: 14, color: Colors.teal)),
          ),
          SizedBox(
            width: 150,
            child: Text(supplier.contactInfo ?? "غير محدد", style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.person, color: Colors.purple, size: 20),
                  tooltip: 'ملف المورد',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupplierProfileScreen(supplier: supplier),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  tooltip: 'تعديل بيانات المورد',
                  onPressed: () => _showEditDialog(context, ref, supplier.id, supplier.name, supplier.contactInfo),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'أرشفة / حذف',
                  onPressed: () => _showDeleteConfirmDialog(context, ref, supplier.id, supplier.name),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.blue),
              SizedBox(width: 8),
              Text('إضافة مورد / وكيل جديد'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم المورد (عربي أو إنجليزي)', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف / وسيلة التواصل', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final success = await ref.read(suppliersNotifierProvider.notifier).add(
                      name: nameController.text.trim(),
                      contactInfo: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    );
                if (success && context.mounted) Navigator.pop(context);
              },
              child: const Text('حفظ المورد'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, int id, String currentName, String? currentPhone) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone ?? '');
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل بيانات المورد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم المورد', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف / وسيلة التواصل', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final success = await ref.read(suppliersNotifierProvider.notifier).updateSupplier(
                      id,
                      nameController.text.trim(),
                    );
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
          content: Text('هل أنت متأكد من رغبتك في أرشفة المورد "$name"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final success = await ref.read(suppliersNotifierProvider.notifier).deleteSupplier(id);
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
