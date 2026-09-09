import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/entities/purchase_returns_entity.dart';
import '../../domain/repositories/purchase_returns_repository.dart';
import 'package:intl/intl.dart';

class PurchaseReturnsScreen extends StatefulWidget {
  const PurchaseReturnsScreen({super.key});

  @override
  State<PurchaseReturnsScreen> createState() => _PurchaseReturnsScreenState();
}

class _PurchaseReturnsScreenState extends State<PurchaseReturnsScreen> {
  final _repo = sl<PurchaseReturnsRepository>();
  List<PurchaseReturnEntity> _returns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.getAllPurchaseReturns();
    setState(() {
      _returns = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مردودات المشتريات'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _returns.isEmpty
              ? const Center(child: Text('لا توجد مردودات مشتريات'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _returns.length,
                  itemBuilder: (context, index) {
                    final pr = _returns[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ExpansionTile(
                        title: Text('رقم المرتجع: ${pr.referenceNumber}'),
                        subtitle: Text('المورد: ${pr.supplierName} | الإجمالي: ${pr.totalAmount} | التاريخ: ${DateFormat('yyyy-MM-dd').format(pr.createdAt)}'),
                        children: [
                          DataTable(
                            columns: const [
                              DataColumn(label: Text('الصنف')),
                              DataColumn(label: Text('الكمية')),
                              DataColumn(label: Text('السعر')),
                              DataColumn(label: Text('الإجمالي')),
                              DataColumn(label: Text('السبب')),
                            ],
                            rows: pr.items.map((item) {
                              return DataRow(cells: [
                                DataCell(Text(item.medicineName)),
                                DataCell(Text('${item.quantity}')),
                                DataCell(Text('${item.unitPrice}')),
                                DataCell(Text('${item.subtotal}')),
                                DataCell(Text(item.reason)),
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
