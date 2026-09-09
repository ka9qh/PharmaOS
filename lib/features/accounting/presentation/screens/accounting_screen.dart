// شاشة أرصدة الموردين والتسديدات (Accounting) - تعرض ما يتبقى لكل مورد
// وتتيح تسجيل تسديد دفعة جديدة (تُخصم من المتبقي فورًا).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/accounting_provider.dart';
import '../controllers/accounting_controller.dart';
import '../widgets/accounting_widget.dart';
import '../../domain/entities/accounting_entity.dart';

class AccountingScreen extends ConsumerWidget {
  const AccountingScreen({super.key});

  Future<void> _showPayDialog(BuildContext context, WidgetRef ref, SupplierBalance balance) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String? amountError;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('تسديد لـ ${balance.supplierName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('المتبقي حاليًا: ${balance.remainingDebt.toStringAsFixed(0)} ريال'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'المبلغ المسدَّد', errorText: amountError),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final error = AccountingController.validatePaymentAmount(
                    amountController.text, balance.remainingDebt);
                if (error != null) {
                  setState(() => amountError = error);
                  return;
                }
                final ok = await ref.read(accountingNotifierProvider.notifier).recordPayment(
                      supplierId: balance.supplierId,
                      amount: double.parse(amountController.text),
                      notes: notesController.text.isEmpty ? null : notesController.text,
                    );
                if (ok && context.mounted) Navigator.pop(context);
              },
              child: const Text('تأكيد التسديد'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountingNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('أرصدة الموردين والتسديدات')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.balances.isEmpty
                ? const Center(child: Text('لا توجد مشتريات مسجّلة بعد'))
                : ListView.builder(
                    itemCount: state.balances.length,
                    itemBuilder: (context, index) {
                      final balance = state.balances[index];
                      return SupplierBalanceRow(
                        balance: balance,
                        onPay: () => _showPayDialog(context, ref, balance),
                      );
                    },
                  ),
      ),
    );
  }
}
