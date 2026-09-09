import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:io';

import '../../domain/entities/suppliers_entity.dart';
import '../providers/supplier_profile_provider.dart';
import '../../../purchases/domain/entities/purchases_entity.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../../core/entities/ledger_entry_entity.dart';
import 'supplier_ledger_screen.dart';

class SupplierProfileScreen extends ConsumerWidget {
  final SupplierEntity supplier;

  const SupplierProfileScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplierProfileProvider(supplier.id));
    final currency = NumberFormat.currency(symbol: 'ريال', decimalDigits: 0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text('ملف المورد: ${supplier.name}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.receipt_long),
                tooltip: 'كشف حساب تفصيلي مع طباعة ومطابقة',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierLedgerScreen(supplier: supplier),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث البيانات',
                onPressed: () => ref
                    .read(supplierProfileProvider(supplier.id).notifier)
                    .loadProfileData(supplier.id),
              ),
            ],
            bottom: const TabBar(
              indicatorColor: Colors.teal,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(text: 'كشف الحساب', icon: Icon(Icons.account_balance_wallet)),
                Tab(text: 'الفواتير والمشتريات', icon: Icon(Icons.receipt)),
                Tab(text: 'الأصناف (الأدوية)', icon: Icon(Icons.medication)),
              ],
            ),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                            const SizedBox(height: 16),
                            Text(
                              state.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, color: Colors.red),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                              onPressed: () => ref
                                  .read(supplierProfileProvider(supplier.id).notifier)
                                  .loadProfileData(supplier.id),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TabBarView(
                      children: [
                        _buildLedgerTab(context, state.ledgerEntries, currency),
                        _buildInvoicesTab(state.purchases, currency),
                        _buildMedicinesTab(state.medicines, currency),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildLedgerTab(
    BuildContext context,
    List<LedgerEntryEntity> ledgerEntries,
    NumberFormat currency,
  ) {
    if (ledgerEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'لا توجد حركات مالية مسجلة لهذا المورد',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final totalCredit = ledgerEntries.fold<double>(0, (sum, e) => sum + e.credit);
    final totalDebit = ledgerEntries.fold<double>(0, (sum, e) => sum + e.debit);
    final finalBalance = totalCredit - totalDebit;
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

    return Column(
      children: [
        // ملخص الحساب
        Container(
          padding: const EdgeInsets.all(12.0),
          color: Colors.blueGrey.shade50,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي المشتريات (له)', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      const SizedBox(height: 2),
                      Text(currency.format(totalCredit), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي المسدد (عليه)', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      const SizedBox(height: 2),
                      Text(currency.format(totalDebit), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: finalBalance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: finalBalance > 0 ? Colors.red.shade300 : Colors.green.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finalBalance > 0 ? 'المتبقي له (دين)' : (finalBalance < 0 ? 'رصيد لنا' : 'الحساب خالص'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: finalBalance > 0 ? Colors.red.shade900 : Colors.green.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currency.format(finalBalance.abs()),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: finalBalance > 0 ? Colors.red.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // قائمة الحركات
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: ledgerEntries.length,
            itemBuilder: (context, index) {
              final entry = ledgerEntries[index];
              final isCredit = entry.credit > 0;
              final amount = isCredit ? entry.credit : entry.debit;

              return Card(
                elevation: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCredit ? Colors.blue.shade50 : Colors.green.shade50,
                    child: Icon(
                      isCredit ? Icons.shopping_bag_outlined : Icons.payment,
                      color: isCredit ? Colors.blue.shade700 : Colors.green.shade700,
                      size: 20,
                    ),
                  ),
                  title: Text(entry.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(
                    '${dateFormatter.format(entry.date)}  •  مرجع: ${entry.referenceNumber}',
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isCredit ? "+" : "-"} ${currency.format(amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isCredit ? Colors.blue.shade800 : Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'الرصيد: ${currency.format(entry.balance.abs())} ${entry.balance > 0 ? "(له)" : (entry.balance < 0 ? "(لنا)" : "")}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: entry.balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab(List<PurchaseEntity> purchases, NumberFormat currency) {
    if (purchases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('لا توجد فواتير مشتريات لهذا المورد', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    final dateFormatter = DateFormat('yyyy-MM-dd');

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final purchase = purchases[index];
        final remaining = purchase.totalAmount - purchase.paidAmount;
        final isFullyPaid = remaining <= 0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isFullyPaid ? Colors.green.shade100 : Colors.amber.shade100,
              child: Icon(
                isFullyPaid ? Icons.check_circle : Icons.pending,
                color: isFullyPaid ? Colors.green.shade800 : Colors.amber.shade900,
              ),
            ),
            title: Text(
              'فاتورة #${purchase.purchaseNumber} ${purchase.supplierInvoiceRef != null ? "(مرجع: ${purchase.supplierInvoiceRef})" : ""}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'التاريخ: ${dateFormatter.format(purchase.createdAt)}  •  الحالة: ${isFullyPaid ? "مسددة بالكامل" : "متبقي آجل"}',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            trailing: Text(
              currency.format(purchase.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المبلغ الإجمالي: ${currency.format(purchase.totalAmount)}'),
                        Text('المسدد: ${currency.format(purchase.paidAmount)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        Text(
                          'المتبقي: ${currency.format(remaining)}',
                          style: TextStyle(
                            color: remaining > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (purchase.invoiceImagePath != null && purchase.invoiceImagePath!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('صورة الفاتورة المرفقة:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(purchase.invoiceImagePath!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 100,
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const Text('تعذر تحميل الصورة أو تم نقل الملف', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMedicinesTab(List<MedicineEntity> medicines, NumberFormat currency) {
    if (medicines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('لم يتم توريد أي أصناف من هذا المورد حتى الآن', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: medicines.length,
      itemBuilder: (context, index) {
        final medicine = medicines[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade50,
              child: const Icon(Icons.medication, color: Colors.teal),
            ),
            title: Text(medicine.nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(
              '${medicine.nameEn ?? ""}  •  الباركود: ${medicine.barcode}',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'شراء: ${currency.format(medicine.purchasePrice)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
                ),
                Text(
                  'بيع: ${currency.format(medicine.sellingPrice)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

