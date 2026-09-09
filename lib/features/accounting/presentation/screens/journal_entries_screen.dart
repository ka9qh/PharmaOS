import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/repositories/general_ledger_repository.dart';
import '../../domain/entities/accounting_entities.dart';

class JournalEntriesScreen extends StatefulWidget {
  const JournalEntriesScreen({super.key});

  @override
  State<JournalEntriesScreen> createState() => _JournalEntriesScreenState();
}

class _JournalEntriesScreenState extends State<JournalEntriesScreen> {
  final _glRepo = sl<GeneralLedgerRepository>();
  List<JournalEntryEntity> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final entries = await _glRepo.getJournalEntries();
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القيود اليومية المحاسبية'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ExpansionTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.receipt_long, color: Colors.white),
                    ),
                    title: Text('${entry.referenceNumber} - ${entry.description}'),
                    subtitle: Text('المصدر: ${entry.source} | التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(entry.date)}'),
                    children: [
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('الحساب')),
                          DataColumn(label: Text('مدين (Debit)')),
                          DataColumn(label: Text('دائن (Credit)')),
                          DataColumn(label: Text('البيان')),
                        ],
                        rows: entry.lines.map((line) {
                          return DataRow(cells: [
                            DataCell(Text(line.accountName)),
                            DataCell(Text(line.debit > 0 ? line.debit.toStringAsFixed(2) : '-')),
                            DataCell(Text(line.credit > 0 ? line.credit.toStringAsFixed(2) : '-')),
                            DataCell(Text(line.description ?? '-')),
                          ]);
                        }).toList(),
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }
}
