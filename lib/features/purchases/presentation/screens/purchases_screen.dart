import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/purchases_entity.dart';
import '../providers/purchases_provider.dart';
import '../widgets/purchases_widget.dart';
import 'purchase_form_screen.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all'; // 'all', 'unpaid', 'paid'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchasesNotifierProvider);

    // فلترة وبحث الفواتير
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = state.items.where((p) {
      if (_filterStatus == 'unpaid' && p.remainingAmount <= 0) return false;
      if (_filterStatus == 'paid' && p.remainingAmount > 0) return false;

      if (query.isNotEmpty) {
        final matchNum = p.purchaseNumber.toLowerCase().contains(query);
        final matchSup = p.supplierName.toLowerCase().contains(query);
        final matchRef = p.supplierInvoiceRef?.toLowerCase().contains(query) ?? false;
        if (!matchNum && !matchSup && !matchRef) return false;
      }
      return true;
    }).toList();

    // حساب الإجماليات
    final totalPurchases = state.items.fold<double>(0, (sum, p) => sum + p.totalAmount);
    final totalPaid = state.items.fold<double>(0, (sum, p) => sum + p.paidAmount);
    final totalDebt = state.items.fold<double>(0, (sum, p) => sum + p.remainingAmount);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('المشتريات وتوريد الأدوية'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () => ref.read(purchasesNotifierProvider.notifier).loadAll(),
            ),
          ],
        ),
        body: Column(
          children: [
            // شريط الإحصائيات العامة
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard(
                        title: 'إجمالي المشتريات',
                        amount: totalPurchases,
                        color: Colors.blue.shade700,
                        bgColor: Colors.blue.shade50,
                        icon: Icons.shopping_bag_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        title: 'المدفوع',
                        amount: totalPaid,
                        color: Colors.green.shade700,
                        bgColor: Colors.green.shade50,
                        icon: Icons.check_circle_outline,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        title: 'ديون للموردين',
                        amount: totalDebt,
                        color: Colors.orange.shade800,
                        bgColor: Colors.orange.shade50,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // شريط البحث
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم فاتورة الشراء أو اسم المورد أو الرقم المرجعي...',
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  // أزرار الفلترة السريعة
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          selected: _filterStatus == 'all',
                          label: Text('جميع فواتير الشراء (${state.items.length})'),
                          selectedColor: Colors.blue.shade100,
                          onSelected: (_) => setState(() => _filterStatus = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _filterStatus == 'unpaid',
                          label: Text(
                            'متبقي عليها دين (${state.items.where((p) => p.remainingAmount > 0).length})',
                          ),
                          selectedColor: Colors.orange.shade100,
                          onSelected: (_) => setState(() => _filterStatus = 'unpaid'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _filterStatus == 'paid',
                          label: Text(
                            'مسددة بالكامل (${state.items.where((p) => p.remainingAmount <= 0).length})',
                          ),
                          selectedColor: Colors.green.shade100,
                          onSelected: (_) => setState(() => _filterStatus = 'paid'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // قائمة الفواتير
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('لا توجد فواتير شراء مطابقة للبحث', style: TextStyle(color: Colors.grey, fontSize: 15)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) => PurchaseListTile(purchase: filteredItems[index]),
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PurchaseFormScreen()),
            );
            ref.read(purchasesNotifierProvider.notifier).loadAll();
          },
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('فاتورة شراء جديدة'),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required double amount,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                  Text(
                    '${amount.toStringAsFixed(0)} ر.ي',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
