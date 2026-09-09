// شاشة الفواتير الشاملة (جميع الفواتير، المبيعات، المشتريات، المرتجعات، المصاريف)
// بحث متقدم وخارق: باسم الفاتورة، رقم الفاتورة، اسم العلاج، المبلغ، اسم الشركة، اسم المورد/العميل، والتاريخ
// تدعم تسمية الفواتير وعرض التفاصيل والطباعة الفورية وتسجيل المرتجعات

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/invoices_provider.dart';
import '../../domain/entities/invoice_entity.dart';
import 'invoice_details_screen.dart';
import '../../../returns/presentation/screens/returns_screen.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref, InvoicesState state) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: state.fromDate != null && state.toDate != null
          ? DateTimeRange(start: state.fromDate!, end: state.toDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      ref.read(invoicesProvider.notifier).setDateRange(picked.start, picked.end);
    }
  }

  Widget _buildInvoiceCard(InvoiceEntity inv) {
    final hasCustomName = inv.invoiceName != null && inv.invoiceName!.isNotEmpty;

    // تحديد اللون والأيقونة والنوع
    Color primaryColor;
    Color bgColor;
    IconData iconData;
    String typeLabel;

    if (inv.isCustomerReturn) {
      primaryColor = Colors.orange.shade800;
      bgColor = Colors.orange.shade50;
      iconData = Icons.assignment_return;
      typeLabel = 'مرتجع مبيعات';
    } else if (inv.isVendorReturn) {
      primaryColor = Colors.purple.shade800;
      bgColor = Colors.purple.shade50;
      iconData = Icons.assignment_return_outlined;
      typeLabel = 'مرتجع مشتريات';
    } else if (inv.isExpense) {
      primaryColor = Colors.brown.shade700;
      bgColor = Colors.brown.shade50;
      iconData = Icons.money_off_outlined;
      typeLabel = 'سند صرف مصروف';
    } else if (inv.isSale) {
      primaryColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
      iconData = Icons.point_of_sale;
      typeLabel = inv.paymentMethod == 'آجل' ? 'بيع آجل' : 'بيع نقدي';
    } else {
      primaryColor = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
      iconData = Icons.shopping_bag_outlined;
      typeLabel = 'مشتريات';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceDetailsScreen(
                invoiceId: inv.id,
                invoice: inv,
                invoiceNumber: inv.invoiceNumber,
                invoiceType: inv.type,
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: bgColor,
          child: Icon(iconData, color: primaryColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                hasCustomName ? inv.invoiceName! : inv.invoiceNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
            if (inv.status != null && inv.status != 'completed') ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: inv.status == 'returned' ? Colors.red.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  inv.status == 'returned' ? 'مرتجع بالكامل' : 'مرتجع جزئي',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: inv.status == 'returned' ? Colors.red.shade800 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'الرقم: ${inv.invoiceNumber}',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                if (inv.partyName.isNotEmpty)
                  Text(
                    '${inv.isSale || inv.isCustomerReturn ? "العميل" : (inv.isExpense ? "المستفيد/البند" : "المورد")}: ${inv.partyName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            if (inv.originalInvoiceRef != null && inv.originalInvoiceRef!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'أصل الفاتورة: ${inv.originalInvoiceRef}',
                style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold),
              ),
            ],
            if (inv.reason != null && inv.reason!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'ملاحظات/السبب: ${inv.reason}',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(inv.date)} | الأصناف: ${inv.items.length} صنف/بند',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${inv.totalAmount.toStringAsFixed(0)} ر.ي',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: primaryColor,
                  ),
                ),
                if (inv.isPurchase && inv.paidAmount != null)
                  Text(
                    'المدفوع: ${inv.paidAmount!.toStringAsFixed(0)} | المتبقي: ${(inv.totalAmount - inv.paidAmount!).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: (inv.totalAmount - inv.paidAmount!) > 0 ? Colors.red : Colors.green,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceDetailsScreen(
                      invoiceId: inv.id,
                      invoice: inv,
                      invoiceNumber: inv.invoiceNumber,
                      invoiceType: inv.type,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoicesProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('الفواتير الشاملة'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: const Icon(Icons.receipt_long),
                text: 'جميع الفواتير (${state.allInvoices.length})',
              ),
              Tab(
                icon: const Icon(Icons.point_of_sale),
                text: 'فواتير المبيعات (${state.salesInvoices.length})',
              ),
              Tab(
                icon: const Icon(Icons.shopping_cart),
                text: 'فواتير المشتريات (${state.purchaseInvoices.length})',
              ),
              Tab(
                icon: const Icon(Icons.assignment_return),
                text: 'فواتير المرتجعات (${state.returnInvoices.length})',
              ),
              Tab(
                icon: const Icon(Icons.money_off),
                text: 'فواتير المصاريف (${state.expenseInvoices.length})',
              ),
            ],
          ),
          actions: [
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade50, foregroundColor: Colors.deepOrange),
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('تسجيل مرتجع جديد', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReturnsScreen()),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث الفواتير',
              onPressed: () => ref.read(invoicesProvider.notifier).loadInvoices(),
            ),
          ],
        ),
        body: Column(
          children: [
            // شريط البحث الشامل والفلترة بالتاريخ
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.blue),
                        hintText: 'ابحث باسم الفاتورة، رقمها، اسم العميل، التاجر/المورد، أو اسم العلاج/المصروف...',
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(invoicesProvider.notifier).setSearchQuery('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                      ),
                      onChanged: (val) => ref.read(invoicesProvider.notifier).setSearchQuery(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      state.fromDate != null && state.toDate != null
                          ? '${DateFormat('MM/dd').format(state.fromDate!)} - ${DateFormat('MM/dd').format(state.toDate!)}'
                          : 'الفترة الزمنية',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _pickDateRange(context, ref, state),
                  ),
                  if (state.fromDate != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      tooltip: 'إلغاء فلتر التاريخ',
                      onPressed: () => ref.read(invoicesProvider.notifier).setDateRange(null, null),
                    ),
                  ],
                ],
              ),
            ),

            // محتوى التبويبات الخمسة
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. جميع الفواتير
                        state.allInvoices.isEmpty
                            ? const Center(child: Text('لا توجد فواتير مسجلة مطابقة للبحث'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 8),
                                itemCount: state.allInvoices.length,
                                itemBuilder: (context, index) => _buildInvoiceCard(state.allInvoices[index]),
                              ),

                        // 2. فواتير المبيعات
                        state.salesInvoices.isEmpty
                            ? const Center(child: Text('لا توجد فواتير مبيعات مطابقة للبحث'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 8),
                                itemCount: state.salesInvoices.length,
                                itemBuilder: (context, index) => _buildInvoiceCard(state.salesInvoices[index]),
                              ),

                        // 3. فواتير المشتريات
                        state.purchaseInvoices.isEmpty
                            ? const Center(child: Text('لا توجد فواتير مشتريات مطابقة للبحث'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 8),
                                itemCount: state.purchaseInvoices.length,
                                itemBuilder: (context, index) => _buildInvoiceCard(state.purchaseInvoices[index]),
                              ),

                        // 4. فواتير المرتجعات
                        state.returnInvoices.isEmpty
                            ? const Center(child: Text('لا توجد فواتير مرتجعات مطابقة للبحث'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 8),
                                itemCount: state.returnInvoices.length,
                                itemBuilder: (context, index) => _buildInvoiceCard(state.returnInvoices[index]),
                              ),

                        // 5. فواتير المصاريف
                        state.expenseInvoices.isEmpty
                            ? const Center(child: Text('لا توجد فواتير مصاريف مطابقة للبحث'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 8),
                                itemCount: state.expenseInvoices.length,
                                itemBuilder: (context, index) => _buildInvoiceCard(state.expenseInvoices[index]),
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


