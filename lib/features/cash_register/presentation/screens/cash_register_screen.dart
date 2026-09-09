import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cash_register_provider.dart';
import 'package:intl/intl.dart';

class CashRegisterScreen extends ConsumerWidget {
  const CashRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cashRegisterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق الصيدلية والمحافظ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(cashRegisterProvider.notifier).loadData(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar: Wallets & Cash Selector
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                _buildSidebarItem(
                  context,
                  title: 'الصندوق النقدي',
                  balance: state.currentCashBalance,
                  isSelected: state.selectedWalletId == null,
                  onTap: () => ref.read(cashRegisterProvider.notifier).selectWallet(null),
                  icon: Icons.point_of_sale,
                  color: Colors.green,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المحافظ الإلكترونية', style: TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: () => _showAddWalletDialog(context, ref),
                        tooltip: 'إضافة محفظة',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.wallets.length,
                    itemBuilder: (context, index) {
                      final w = state.wallets[index];
                      return _buildSidebarItem(
                        context,
                        title: w.name,
                        balance: w.balance,
                        isSelected: state.selectedWalletId == w.id,
                        onTap: () => ref.read(cashRegisterProvider.notifier).selectWallet(w.id),
                        icon: Icons.account_balance_wallet,
                        color: Colors.blue,
                        onDelete: () => _confirmDeleteWallet(context, ref, w.id, w.name),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main Content: Ledger Transactions
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildLedger(state),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required String title,
    required double balance,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    VoidCallback? onDelete,
  }) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.ي', decimalDigits: 0);
    return ListTile(
      leading: Icon(icon, color: isSelected ? color : Colors.grey),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(currencyFormat.format(balance),
          style: TextStyle(color: balance >= 0 ? Colors.green.shade700 : Colors.red, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedTileColor: color.withOpacity(0.1),
      onTap: onTap,
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: onDelete,
            )
          : null,
    );
  }

  Widget _buildLedger(CashRegisterState state) {
    if (state.errorMessage != null) {
      return Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (state.currentTransactions.isEmpty) {
      return const Center(child: Text('لا توجد حركات مالية مسجلة'));
    }

    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 0);
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

    final totalIn = state.currentTransactions
        .where((t) => t.type == 'IN')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalOut = state.currentTransactions
        .where((t) => t.type == 'OUT')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalReturnsOut = state.currentTransactions
        .where((t) => t.source == 'return' && t.type == 'OUT')
        .fold<double>(0, (sum, t) => sum + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // بطاقات التحليل المالي السريع للصندوق/المحفظة
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blueGrey.shade50,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي الوارد (IN)', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      const SizedBox(height: 4),
                      Text('+${currencyFormat.format(totalIn)} ر.ي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي الخارج والمصاريف (OUT)', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      const SizedBox(height: 4),
                      Text('-${currencyFormat.format(totalOut)} ر.ي', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مرتجعات المبيعات الخارجة', style: TextStyle(fontSize: 11, color: Colors.deepOrange)),
                      const SizedBox(height: 4),
                      Text('${currencyFormat.format(totalReturnsOut)} ر.ي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الرصيد الصافي الحالي', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text('${currencyFormat.format(totalIn - totalOut)} ر.ي', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: state.currentTransactions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tx = state.currentTransactions[index];
              final isOut = tx.type == 'OUT';
              final isReturn = tx.source == 'return';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isReturn
                      ? Colors.orange.shade100
                      : (isOut ? Colors.red.shade100 : Colors.green.shade100),
                  child: Icon(
                    isReturn
                        ? Icons.assignment_return
                        : (isOut ? Icons.arrow_upward : Icons.arrow_downward),
                    color: isReturn
                        ? Colors.deepOrange
                        : (isOut ? Colors.red : Colors.green),
                  ),
                ),
                title: Text(tx.description),
                subtitle: Text(dateFormat.format(tx.date)),
                trailing: Text(
                  '${isOut ? "-" : "+"}${currencyFormat.format(tx.amount)} ر.ي',
                  style: TextStyle(
                    color: isOut ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddWalletDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة محفظة إلكترونية جديدة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم المحفظة (مثال: جيب، جوالي)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(cashRegisterProvider.notifier).addWallet(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWallet(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف محفظة'),
        content: Text('هل أنت متأكد من حذف محفظة "$name"؟\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(cashRegisterProvider.notifier).deleteWallet(id);
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
