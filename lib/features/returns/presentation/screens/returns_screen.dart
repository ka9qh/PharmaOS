// شاشة المرتجعات - تبويبان: مرتجع عميل (من فاتورة بيع) ومرتجع مورد (من فاتورة شراء)
// لا يوجد "حذف فاتورة" إطلاقًا - كل إرجاع هو قيد عكسي جديد يحافظ على السجل الكامل
// (راجع docs/SECURITY_GUIDELINES.md).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/returns_provider.dart';
import '../widgets/returns_widget.dart';
import '../../domain/entities/returns_entity.dart';
import 'return_form_screen.dart';

class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key});

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _saleSearchController = TextEditingController();
  final _purchaseSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => ref.read(returnsNotifierProvider.notifier).reset());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _saleSearchController.dispose();
    _purchaseSearchController.dispose();
    super.dispose();
  }

  void _navigateToCustomerReturnForm(SaleItemLookup item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReturnFormScreen(
          isSaleReturn: true,
          saleItem: item,
          onReturnSuccess: () {
            _saleSearchController.clear();
            ref.read(returnsNotifierProvider.notifier).reset();
          },
        ),
      ),
    );
  }

  void _navigateToVendorReturnForm(PurchaseItemLookup item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReturnFormScreen(
          isSaleReturn: false,
          purchaseItem: item,
          onReturnSuccess: () {
            _purchaseSearchController.clear();
            ref.read(returnsNotifierProvider.notifier).reset();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(returnsNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المرتجعات'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'مرتجع عميل'),
              Tab(text: 'مرتجع مورد'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // ---------------- مرتجع عميل ----------------
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _saleSearchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'رقم الفاتورة (مثال: INV-20260706-0001)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) =>
                        ref.read(returnsNotifierProvider.notifier).searchSale(value),
                  ),
                ),
                if (state.errorMessage != null)
                  Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                if (state.successMessage != null)
                  Text(state.successMessage!, style: const TextStyle(color: Colors.green)),
                if (state.isSearching) const CircularProgressIndicator(),
                if (state.saleResult != null)
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.saleResult!.items.length,
                      itemBuilder: (context, index) {
                        final item = state.saleResult!.items[index];
                        return ReturnableLineTile(
                          medicineName: item.medicineName,
                          maxReturnable: item.maxReturnable,
                          subtitleExtra: 'الكمية الأصلية: ${item.originalQuantity}',
                          onTap: () => _navigateToCustomerReturnForm(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
            // ---------------- مرتجع مورد ----------------
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _purchaseSearchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'رقم فاتورة الشراء (مثال: PUR-20260706-0001)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) =>
                        ref.read(returnsNotifierProvider.notifier).searchPurchase(value),
                  ),
                ),
                if (state.errorMessage != null)
                  Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                if (state.successMessage != null)
                  Text(state.successMessage!, style: const TextStyle(color: Colors.green)),
                if (state.isSearching) const CircularProgressIndicator(),
                if (state.purchaseResult != null)
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.purchaseResult!.items.length,
                      itemBuilder: (context, index) {
                        final item = state.purchaseResult!.items[index];
                        return ReturnableLineTile(
                          medicineName: item.medicineName,
                          maxReturnable: item.maxReturnable,
                          subtitleExtra: 'الكمية الأصلية: ${item.originalQuantity}',
                          onTap: () => _navigateToVendorReturnForm(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
