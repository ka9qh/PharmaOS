// شاشة التسوية الجردية والمطابقة الفعلية للمخزون - PharmaOS
// تتيح: إدخال الجرد الفعلي، احتساب الفوارق آلياً (فائض/عجز)، معالجة الفروقات في الدفعات، وزر الرجوع والبحث

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/inventory_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/multi_unit_quantity_widget.dart';

class InventoryReconciliationScreen extends ConsumerStatefulWidget {
  const InventoryReconciliationScreen({super.key});

  @override
  ConsumerState<InventoryReconciliationScreen> createState() =>
      _InventoryReconciliationScreenState();
}

class _InventoryReconciliationScreenState
    extends ConsumerState<InventoryReconciliationScreen> {
  final _searchController = TextEditingController();
  final Map<int, TextEditingController> _actualControllers = {};
  int _selectedFilter = 0; // 0: الكل, 1: المتوفر (>0), 2: بدون رصيد (0)

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(inventoryNotifierProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reconcile(int medicineId, double systemQty, String name, int? actualPills) async {
    if (actualPills == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال الكمية الفعلية أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final actual = actualPills.toDouble();
    if (actual == systemQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الكمية الفعلية تطابق الكمية الدفترية تماماً. لا يوجد فارق للتسوية ✓'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final difference = actual - systemQty;
    final isSurplus = difference > 0;
    final reasonCtrl = TextEditingController(
      text: isSurplus ? 'فائض جردي' : 'عجز جردي',
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isSurplus ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: isSurplus ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('تسوية جردية: $name', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSurplus ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSurplus ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الكمية المسجلة (الدفترية):'),
                        Text(
                          '$systemQty',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الكمية الفعلية (الجرد):'),
                        Text(
                          '$actual',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الفارق (${isSurplus ? "فائض" : "عجز"}):'),
                        Text(
                          '${isSurplus ? "+" : ""}$difference',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSurplus ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'سبب التسوية / ملاحظات *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('اعتماد وترحيل التسوية'),
              style: FilledButton.styleFrom(
                backgroundColor: isSurplus ? Colors.green.shade700 : Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final currentUser = ref.read(authNotifierProvider).user;
      final success = await ref.read(inventoryNotifierProvider.notifier).reconcileStock(
            medicineId: medicineId,
            actualQuantity: actual,
            systemQuantity: systemQty,
            note: reasonCtrl.text.trim(),
            userId: currentUser?.id,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت تسوية مخزون "$name" بنجاح ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryNotifierProvider);

    // تصفية العناصر بناءً على التبويب المختار
    final filteredItems = state.items.where((item) {
      if (_selectedFilter == 1) return item.totalQuantity > 0;
      if (_selectedFilter == 2) return item.totalQuantity <= 0;
      return true;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'رجوع للرئيسية',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go('/dashboard');
              }
            },
          ),
          title: const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: Colors.blue),
              SizedBox(width: 8),
              Text('التسوية الجردية (Inventory Reconciliation)'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث المخزون',
              onPressed: () => ref.read(inventoryNotifierProvider.notifier).loadAll(),
            ),
          ],
        ),
        body: Column(
          children: [
            // شريط البحث المباشر
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'بحث عن دواء للجرد والمطابقة...',
                  prefixIcon: const Icon(Icons.search, color: Colors.blue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(inventoryNotifierProvider.notifier).search('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (val) => ref.read(inventoryNotifierProvider.notifier).search(val),
              ),
            ),

            // أزرار التصفية السريعة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('جميع الأصناف (${state.items.length})'),
                    selected: _selectedFilter == 0,
                    onSelected: (_) => setState(() => _selectedFilter = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('المتوفر فقط (>0)'),
                    selected: _selectedFilter == 1,
                    onSelected: (_) => setState(() => _selectedFilter = 1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('أصناف بدون رصيد (0)'),
                    selected: _selectedFilter == 2,
                    onSelected: (_) => setState(() => _selectedFilter = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (state.errorMessage != null)
              Container(
                color: Colors.red.shade50,
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            // قائمة الأدوية للتسوية
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredItems.isEmpty
                      ? const Center(child: Text('لا توجد أصناف تطابق معايير البحث'))
                      : Column(
                          children: [
                            // رأس الجدول (Table Header)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade900,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(flex: 2, child: Text('رقم/كود الصنف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 4, child: Text('اسم الصنف الدوائي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('الرصيد الدفتري', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('الجرد الفعلي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('الفارق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('إجراء التسوية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            // قائمة الأصناف
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                  ],
                                ),
                                child: ListView.separated(
                                  itemCount: filteredItems.length,
                                  separatorBuilder: (ctx, idx) => const Divider(height: 1),
                                  itemBuilder: (ctx, index) {
                                    final item = filteredItems[index];

                                    return _InventoryRow(
                                      item: item,
                                      onReconcile: (actualPills) => _reconcile(item.medicineId, item.totalQuantity.toDouble(), item.medicineName, actualPills),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InventoryRow extends StatefulWidget {
  final dynamic item;
  final ValueChanged<int?> onReconcile;

  const _InventoryRow({
    required this.item,
    required this.onReconcile,
  });

  @override
  State<_InventoryRow> createState() => _InventoryRowState();
}

class _InventoryRowState extends State<_InventoryRow> {
  int? _actualPills;
  double? _difference;

  void _onQuantityChanged(int totalPills, int cartons, int packs, int strips, int pills) {
    setState(() {
      _actualPills = totalPills;
      _difference = totalPills.toDouble() - widget.item.totalQuantity;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color diffColor = Colors.grey.shade700;
    String diffText = '-';
    if (_difference != null) {
      if (_difference! > 0) {
        diffColor = Colors.green;
        diffText = '+${_difference!.toInt()} (فائض)';
      } else if (_difference! < 0) {
        diffColor = Colors.red;
        diffText = '${_difference!.toInt()} (عجز)';
      } else {
        diffColor = Colors.blue;
        diffText = '0 (مطابق)';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('${widget.item.medicineId}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(
            flex: 4,
            child: Text(
              widget.item.medicineName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${widget.item.totalQuantity}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: MultiUnitQuantityWidget(
                qtyPerCarton: widget.item.qtyPerCarton,
                qtyPerPack: widget.item.qtyPerPack,
                qtyPerStrip: widget.item.qtyPerStrip,
                onChanged: _onQuantityChanged,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              diffText,
              style: TextStyle(fontWeight: FontWeight.bold, color: diffColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('تسوية'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade900,
                elevation: 0,
              ),
              onPressed: () {
                widget.onReconcile(_actualPills);
              },
            ),
          ),
        ],
      ),
    );
  }
}
