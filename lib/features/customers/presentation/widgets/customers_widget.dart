
import 'package:flutter/material.dart';
import '../../domain/entities/customers_entity.dart';

class CustomerListTile extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  
  const CustomerListTile({
    super.key,
    required this.customer,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(customer.name),
      subtitle: customer.phone != null ? Text(customer.phone!) : null,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class CustomerBalanceRow extends StatelessWidget {
  final CustomerBalance balance;
  final VoidCallback onCollect;

  const CustomerBalanceRow({super.key, required this.balance, required this.onCollect});

  @override
  Widget build(BuildContext context) {
    final hasDebt = balance.remainingDebt > 0;
    return ListTile(
      leading: Icon(
        hasDebt ? Icons.warning_amber_rounded : Icons.check_circle_outline,
        color: hasDebt ? Colors.orange : Colors.green,
      ),
      title: Text(balance.customerName),
      subtitle: Text(
        'إجمالي الآجل: ${balance.totalCredit.toStringAsFixed(0)} • '
        'المسدَّد: ${balance.totalPaid.toStringAsFixed(0)} • '
        'المتبقي: ${balance.remainingDebt.toStringAsFixed(0)}',
        style: TextStyle(color: hasDebt ? Colors.orange.shade800 : Colors.green.shade800),
      ),
      trailing: hasDebt ? FilledButton(onPressed: onCollect, child: const Text('تحصيل')) : null,
    );
  }
}

