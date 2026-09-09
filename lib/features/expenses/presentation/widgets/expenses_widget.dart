import 'package:flutter/material.dart';
import '../../domain/entities/expenses_entity.dart';

class ExpenseListTile extends StatelessWidget {
  final ExpenseEntity expense;
  const ExpenseListTile({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.receipt_outlined),
      title: Text(expense.category),
      subtitle: expense.notes != null ? Text(expense.notes!) : null,
      trailing: Text(
        '${expense.amount.toStringAsFixed(0)} ريال',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
      ),
    );
  }
}
