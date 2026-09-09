import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ui_customization_provider.dart';

class UiStringsCustomizationWidget extends ConsumerStatefulWidget {
  const UiStringsCustomizationWidget({super.key});

  @override
  ConsumerState<UiStringsCustomizationWidget> createState() => _UiStringsCustomizationWidgetState();
}

class _UiStringsCustomizationWidgetState extends ConsumerState<UiStringsCustomizationWidget> {
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();

  final Map<String, String> _availableKeys = {
    'pos_checkout_btn': 'نقطة البيع - زر الإتمام',
    'dashboard_sales_card': 'الداشبورد - كرت المبيعات',
    'dashboard_purchases_card': 'الداشبورد - كرت المشتريات',
    'nav_inventory': 'القائمة - المخزون',
    'nav_reports': 'القائمة - التقارير',
  };

  @override
  Widget build(BuildContext context) {
    final uiStrings = ref.watch(uiStringsProvider);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تخصيص مسميات النظام',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'يمكنك تغيير أسماء الأزرار والعناوين في النظام من هنا. اكتب الاسم الجديد وسيتم تغييره فوراً.',
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 32),
            Expanded(
              child: ListView.separated(
                itemCount: _availableKeys.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final key = _availableKeys.keys.elementAt(index);
                  final desc = _availableKeys[key]!;
                  final currentValue = uiStrings[key] ?? '';

                  return ListTile(
                    title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('المفتاح البرمجي: $key'),
                    trailing: SizedBox(
                      width: 300,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: currentValue),
                              decoration: const InputDecoration(
                                labelText: 'الاسم الجديد',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isEmpty) {
                                  ref.read(uiStringsProvider.notifier).deleteString(key);
                                } else {
                                  ref.read(uiStringsProvider.notifier).setString(key, val.trim());
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.restore),
                            tooltip: 'استعادة الافتراضي',
                            onPressed: () {
                              ref.read(uiStringsProvider.notifier).deleteString(key);
                            },
                          )
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
