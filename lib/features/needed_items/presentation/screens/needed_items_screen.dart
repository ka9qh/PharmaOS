// شاشة ملاحظات الأصناف المطلوبة غير المتوفرة (Step 22)
// لوحة صغيرة قابلة للنقر يدوّن فيها صاحب الصيدلية ما يحتاجه الزبائن
// ولا يتوفر حالياً، مع ظهور تذكيرات عبر نظام الإشعارات.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/needed_items_provider.dart';

class NeededItemsScreen extends ConsumerWidget {
  const NeededItemsScreen({super.key});

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final itemController = TextEditingController();
    final notesController = TextEditingController();
    final customerController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة صنف مطلوب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemController,
              decoration: const InputDecoration(labelText: 'اسم الصنف المطلوب *'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: customerController,
              decoration: const InputDecoration(labelText: 'اسم الزبون (اختياري)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              maxLines: 2,
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
              final itemName = itemController.text.trim();
              if (itemName.isEmpty) return;
              await ref.read(neededItemsNotifierProvider.notifier).addItem(
                    itemName: itemName,
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    customerName: customerController.text.trim().isEmpty ? null : customerController.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(neededItemsNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('الأصناف المطلوبة (غير متوفرة)')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text('لا توجد أصناف مطلوبة حالياً', style: TextStyle(fontSize: 16)),
                        Text('اضغط + لإضافة صنف طلبه زبون ولم يتوفر', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.note_alt_outlined, color: Colors.orange),
                          title: Text(item.itemName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.customerName != null)
                                Text('الزبون: ${item.customerName}'),
                              if (item.notes != null) Text(item.notes!),
                              Text(
                                'تاريخ الإضافة: ${DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                tooltip: 'تم التوفير',
                                onPressed: () => ref.read(neededItemsNotifierProvider.notifier).resolveItem(item.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'حذف',
                                onPressed: () => ref.read(neededItemsNotifierProvider.notifier).deleteItem(item.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDialog(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
