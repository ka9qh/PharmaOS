import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallets_provider.dart';

class WalletsManagementWidget extends ConsumerStatefulWidget {
  const WalletsManagementWidget({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
          child: const WalletsManagementWidget(),
        ),
      ),
    );
  }

  @override
  ConsumerState<WalletsManagementWidget> createState() => _WalletsManagementWidgetState();
}

class _WalletsManagementWidgetState extends ConsumerState<WalletsManagementWidget> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsNotifierProvider);

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
                  'المحافظ الإلكترونية',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showWalletDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة محفظة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'بحث في المحافظ...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: walletsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(child: Text('خطأ: $err')),
                data: (wallets) {
                  final filteredItems = wallets.where((item) => item.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                  
                  if (filteredItems.isEmpty) {
                    return const Center(
                      child: Text('لا توجد محافظ مطابقة.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: filteredItems.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final wallet = filteredItems[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Icon(Icons.account_balance_wallet, color: Theme.of(context).primaryColor),
                        ),
                        title: Text(
                          wallet.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('تاريخ الإضافة: ${wallet.createdAt.toString().split(' ')[0]}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showWalletDialog(context, ref, wallet: wallet),
                              tooltip: 'تعديل',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(context, ref, wallet.id, wallet.name),
                              tooltip: 'حذف',
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

  void _showWalletDialog(BuildContext context, WidgetRef ref, {dynamic wallet}) {
    final isEdit = wallet != null;
    final controller = TextEditingController(text: isEdit ? wallet.name : '');
    final formKey = GlobalKey<FormState>();

    final quickSuggestions = [
      'بنك الكريمي',
      'محفظة جوالي',
      'محفظة ون كاش',
      'محفظة فلوسك',
      'كاش موبايل',
      'بنك القطيبي',
    ];

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_note : Icons.account_balance_wallet,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(isEdit ? 'تعديل المحفظة' : 'إضافة محفظة إلكترونية جديدة'),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'اسم المحفظة أو الحساب البنكي *',
                          hintText: 'مثال: بنك الكريمي، محفظة جوالي...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.wallet),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'يرجى إدخال اسم المحفظة';
                          return null;
                        },
                      ),
                      if (!isEdit) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'اقتراحات سريعة للمحافظ المعتمدة:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: quickSuggestions.map((sug) {
                            return ActionChip(
                              label: Text(sug, style: const TextStyle(fontSize: 11)),
                              avatar: const Icon(Icons.add, size: 14),
                              onPressed: () {
                                setDialogState(() {
                                  controller.text = sug;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isEdit ? 'حفظ التعديل' : 'إضافة المحفظة'),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = controller.text.trim();
                      try {
                        if (isEdit) {
                          await ref.read(walletsNotifierProvider.notifier).updateWallet(wallet.id, name);
                        } else {
                          await ref.read(walletsNotifierProvider.notifier).addWallet(name);
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit ? 'تم تعديل المحفظة بنجاح ✓' : 'تمت إضافة المحفظة بنجاح ✓'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف محفظة "$name"؟\n\nتنبيه: إذا كانت هذه المحفظة مستخدمة في عمليات سابقة، قد يسبب حذفها مشكلة في التقارير.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await ref.read(walletsNotifierProvider.notifier).deleteWallet(id);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('لا يمكن الحذف (قد تكون المحفظة مستخدمة)'), backgroundColor: Colors.red),
                    );
                    Navigator.pop(ctx);
                  }
                }
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}
