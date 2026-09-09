import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/di/service_locator.dart';
import '../../domain/entities/customer_statement_entity.dart';
import '../../domain/repositories/customers_repository.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  bool _isLoading = true;
  String? _error;
  CustomerStatementEntity? _statement;

  @override
  void initState() {
    super.initState();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = sl<CustomersRepository>();
      final statement = await repo.getCustomerStatement(widget.customerId);
      if (mounted) {
        setState(() {
          _statement = statement;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل كشف الحساب: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشف حساب العميل'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStatement),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _buildContent(context, _statement!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CustomerStatementEntity statement) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.ي', decimalDigits: 0);
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blueGrey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statement.customerName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (statement.customerPhone != null && statement.customerPhone!.isNotEmpty)
                Text(statement.customerPhone!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي الدين المتبقي:', style: TextStyle(fontSize: 16)),
                  Text(
                    currencyFormat.format(statement.remainingDebt),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: statement.remainingDebt > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Transactions List
        Expanded(
          child: statement.transactions.isEmpty
              ? const Center(child: Text('لا توجد حركات مالية مسجلة لهذا العميل'))
              : ListView.separated(
                  itemCount: statement.transactions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tx = statement.transactions[index];
                    final isSale = tx.type == 'SALE';
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSale ? Colors.red.shade100 : Colors.green.shade100,
                        child: Icon(
                          isSale ? Icons.shopping_cart_checkout : Icons.payments_outlined,
                          color: isSale ? Colors.red : Colors.green,
                        ),
                      ),
                      title: Text(tx.description),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateFormat.format(tx.date)),
                          const SizedBox(height: 4),
                          Text(tx.details, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        ],
                      ),
                      trailing: Text(
                        '${isSale ? "+" : "-"}${currencyFormat.format(tx.amount)}',
                        style: TextStyle(
                          color: isSale ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
