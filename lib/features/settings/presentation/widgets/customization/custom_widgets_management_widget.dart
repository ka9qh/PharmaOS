import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ui_customization_provider.dart';
import '../../../domain/entities/custom_widget_entity.dart';

class CustomWidgetsManagementWidget extends ConsumerWidget {
  const CustomWidgetsManagementWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgetsState = ref.watch(customWidgetsProvider);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'منشئ الأزرار والواجهات المخصصة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة زر مخصص'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'يمكنك إضافة أزرار جديدة في لوحة التحكم (الداشبورد) وتحديد محتواها (روابط أو نصوص مخصصة).',
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 32),
            Expanded(
              child: widgetsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(child: Text('خطأ: $err')),
                data: (widgets) {
                  if (widgets.isEmpty) {
                    return const Center(child: Text('لا توجد أزرار مخصصة حالياً. أضف زراً جديداً!'));
                  }
                  return ListView.separated(
                    itemCount: widgets.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = widgets[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.widgets, color: Colors.blue),
                        ),
                        title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('الموقع: ${item.location} | النوع: ${item.actionType}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: item.isVisible,
                              onChanged: (val) {
                                ref.read(customWidgetsProvider.notifier).updateWidget(
                                      CustomWidgetEntity(
                                        id: item.id,
                                        keyName: item.keyName,
                                        location: item.location,
                                        widgetType: item.widgetType,
                                        label: item.label,
                                        iconName: item.iconName,
                                        colorHex: item.colorHex,
                                        actionType: item.actionType,
                                        actionData: item.actionData,
                                        sortOrder: item.sortOrder,
                                        isVisible: val,
                                      ),
                                    );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                ref.read(customWidgetsProvider.notifier).deleteWidget(item.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, WidgetRef ref) {
    final labelController = TextEditingController();
    final actionDataController = TextEditingController();
    String selectedLocation = 'dashboard';
    String selectedActionType = 'html_page';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إضافة زر مخصص جديد'),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: labelController,
                          decoration: const InputDecoration(labelText: 'اسم الزر', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedLocation,
                          decoration: const InputDecoration(labelText: 'موقع الزر', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'dashboard', child: Text('الداشبورد (الرئيسية)')),
                            DropdownMenuItem(value: 'pos', child: Text('نقطة البيع')),
                          ],
                          onChanged: (val) => setState(() => selectedLocation = val!),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedActionType,
                          decoration: const InputDecoration(labelText: 'نوع المحتوى عند الضغط', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'html_page', child: Text('صفحة نصوص تفاعلية (سياسات / إرشادات)')),
                            DropdownMenuItem(value: 'open_url', child: Text('رابط خارجي (موقع إنترنت)')),
                          ],
                          onChanged: (val) => setState(() => selectedActionType = val!),
                        ),
                        const SizedBox(height: 16),
                        if (selectedActionType == 'open_url')
                          TextFormField(
                            controller: actionDataController,
                            decoration: const InputDecoration(labelText: 'الرابط (URL)', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          )
                        else
                          TextFormField(
                            controller: actionDataController,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'محتوى الصفحة المخصصة (يدعم النصوص البسيطة)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      ref.read(customWidgetsProvider.notifier).addWidget(
                            CustomWidgetEntity(
                              id: 0,
                              keyName: 'custom_btn_${DateTime.now().millisecondsSinceEpoch}',
                              location: selectedLocation,
                              widgetType: 'button',
                              label: labelController.text,
                              actionType: selectedActionType,
                              actionData: actionDataController.text,
                            ),
                          );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('حفظ وإضافة'),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}
