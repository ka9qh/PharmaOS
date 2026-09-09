import 'package:flutter/material.dart';
import '../../domain/entities/accounting_entity.dart';

class SupplierBalanceRow extends StatelessWidget {
  final SupplierBalance balance;
  final VoidCallback onPay;

  const SupplierBalanceRow({super.key, required this.balance, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final hasDebt = balance.remainingDebt > 0;
    return ListTile(
      leading: Icon(
        hasDebt ? Icons.warning_amber_rounded : Icons.check_circle_outline,
        color: hasDebt ? Colors.orange : Colors.green,
      ),
      title: Text(balance.supplierName),
      subtitle: Text(
        'إجمالي المشتريات: ${balance.totalPurchased.toStringAsFixed(0)} • '
        'المدفوع: ${balance.totalPaid.toStringAsFixed(0)} • '
        'المتبقي: ${balance.remainingDebt.toStringAsFixed(0)}',
        style: TextStyle(color: hasDebt ? Colors.orange.shade800 : Colors.green.shade800),
      ),
      trailing: hasDebt
          ? FilledButton(onPressed: onPay, child: const Text('تسديد'))
          : null,
    );
  }
}
