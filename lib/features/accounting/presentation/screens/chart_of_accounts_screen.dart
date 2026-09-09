import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/repositories/general_ledger_repository.dart';
import '../../domain/entities/accounting_entities.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  final _glRepo = sl<GeneralLedgerRepository>();
  List<AccountEntity> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final accounts = await _glRepo.getAllAccounts();
    // ترتيب الحسابات حسب الكود لتبدو كشجرة
    accounts.sort((a, b) => a.code.compareTo(b.code));
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل الحسابات (شجرة الحسابات)'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                final acc = _accounts[index];
                final isMain = acc.isHeader;
                // إزاحة للحسابات الفرعية
                final paddingLeft = acc.code.length > 1 ? (acc.code.length * 10.0) : 0.0;
                
                return Padding(
                  padding: EdgeInsets.only(right: paddingLeft),
                  child: Card(
                    color: isMain ? Colors.blue.withOpacity(0.1) : Colors.white,
                    elevation: isMain ? 2 : 0,
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: Icon(isMain ? Icons.folder : Icons.account_balance_wallet,
                          color: isMain ? Colors.blue : Colors.grey),
                      title: Text('${acc.code} - ${acc.name}',
                          style: TextStyle(fontWeight: isMain ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(acc.type),
                      trailing: isMain
                          ? null
                          : Text('${acc.balance.toStringAsFixed(2)} ريال',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
