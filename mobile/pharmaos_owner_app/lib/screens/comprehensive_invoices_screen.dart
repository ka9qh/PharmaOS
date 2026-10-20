// شاشة الفواتير الشاملة والرقابة المالية (مبيعات، مشتريات، مرتجعات مع تفاصيل الأصناف) - PharmaOS Owner App
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/models.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';
import '../widgets/luxury_background.dart';
import 'remote_purchases_screen.dart';

enum InvoiceFilterType { all, sales, purchases, returns }

class ComprehensiveInvoicesScreen extends StatefulWidget {
  const ComprehensiveInvoicesScreen({super.key});

  @override
  State<ComprehensiveInvoicesScreen> createState() =>
      _ComprehensiveInvoicesScreenState();
}

class _ComprehensiveInvoicesScreenState
    extends State<ComprehensiveInvoicesScreen> {
  List<CloudSale> _allInvoices = [];
  List<CloudSupplier> _suppliers = [];
  List<CloudMedicine> _medicines = [];
  bool _isLoading = true;
  String _searchQuery = '';
  InvoiceFilterType _selectedFilter = InvoiceFilterType.all;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && _allInvoices.isEmpty) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        OwnerApiService.fetchSales(limit: 200),
        OwnerApiService.fetchSuppliers(),
        OwnerApiService.fetchMedicinesCatalog(),
      ]);

      final sales = results[0] as List<CloudSale>;
      final sups = results[1] as List<CloudSupplier>;
      final meds = results[2] as List<CloudMedicine>;

      if (mounted) {
        setState(() {
          _allInvoices = sales;
          _suppliers = sups;
          _medicines = meds;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InvoiceFilterType _detectInvoiceType(CloudSale invoice) {
    final invNum = invoice.invoiceNumber.toUpperCase();
    if (invNum.startsWith('PUR') ||
        (invoice.cashierName != null &&
            invoice.cashierName!.contains('مورد'))) {
      return InvoiceFilterType.purchases;
    }
    if (invNum.startsWith('RET') ||
        (invoice.cashierName != null &&
            invoice.cashierName!.contains('مرتجع')) ||
        (invoice.customerName != null &&
            invoice.customerName!.contains('مرتجع'))) {
      return InvoiceFilterType.returns;
    }
    return InvoiceFilterType.sales;
  }

  List<CloudSale> get _filteredInvoices {
    return _allInvoices.where((inv) {
      final type = _detectInvoiceType(inv);
      if (_selectedFilter == InvoiceFilterType.sales &&
          type != InvoiceFilterType.sales) {
        return false;
      }
      if (_selectedFilter == InvoiceFilterType.purchases &&
          type != InvoiceFilterType.purchases) {
        return false;
      }
      if (_selectedFilter == InvoiceFilterType.returns &&
          type != InvoiceFilterType.returns) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final numMatch = inv.invoiceNumber.toLowerCase().contains(query);
        final cashierMatch =
            (inv.cashierName ?? '').toLowerCase().contains(query);
        final custMatch = (inv.customerName ?? '').toLowerCase().contains(query);
        final payMatch = inv.paymentMethod.toLowerCase().contains(query);
        return numMatch || cashierMatch || custMatch || payMatch;
      }
      return true;
    }).toList();
  }

  void _showInvoiceDetails(CloudSale invoice) {
    InvoiceDetailsSheet.show(context, invoice, type: _detectInvoiceType(invoice));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInvoices;
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    // إحصائيات سريعة
    double totalSales = 0;
    double totalPurchases = 0;
    double totalReturns = 0;
    for (final inv in _allInvoices) {
      final t = _detectInvoiceType(inv);
      if (t == InvoiceFilterType.sales) totalSales += inv.netAmount;
      if (t == InvoiceFilterType.purchases) totalPurchases += inv.netAmount;
      if (t == InvoiceFilterType.returns) totalReturns += inv.netAmount;
    }

    return LuxuryBackground(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: const Color(0xFF0C1322).withOpacity(0.9),
            elevation: 0,
            title: const Text('الفواتير والرقابة المالية الشاملة 🧾'),
            actions: [
              IconButton(
                tooltip: 'أوامر التوريد والشراء',
                icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.orangeAccent),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RemotePurchasesScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'تحديث البيانات من السيرفر',
                icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
                onPressed: () => _loadData(),
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. بطاقات الإحصائيات السريعة
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    _buildKpiCard(
                      title: 'المبيعات',
                      value: currencyFormat.format(totalSales),
                      color: const Color(0xFF10B981),
                      icon: Icons.point_of_sale_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      title: 'المشتريات',
                      value: currencyFormat.format(totalPurchases),
                      color: const Color(0xFFF59E0B),
                      icon: Icons.shopping_bag_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      title: 'المرتجعات',
                      value: currencyFormat.format(totalReturns),
                      color: const Color(0xFFEF4444),
                      icon: Icons.replay_rounded,
                    ),
                  ],
                ),
              ),

              // 2. شريط البحث والفلاتر
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم الفاتورة، اسم المورد، العميل، الكاشير...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.cyanAccent, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF1E293B).withOpacity(0.7),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // 3. رقائق الفلاتر (Filter Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'الكل (${_allInvoices.length})',
                      type: InvoiceFilterType.all,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'المبيعات 💰',
                      type: InvoiceFilterType.sales,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'فواتير الشراء 📦',
                      type: InvoiceFilterType.purchases,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'المرتجعات 🔄',
                      type: InvoiceFilterType.returns,
                      color: const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // 4. قائمة الفواتير
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.cyanAccent),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded,
                                    size: 54, color: Colors.white24),
                                const SizedBox(height: 12),
                                const Text(
                                  'لا توجد فواتير مطابقة',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadData(),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final inv = filtered[i];
                                return _buildInvoiceCard(inv, currencyFormat);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value ر.ي',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required InvoiceFilterType type,
    required Color color,
  }) {
    final isSelected = _selectedFilter == type;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedFilter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.25) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(CloudSale invoice, NumberFormat format) {
    final type = _detectInvoiceType(invoice);
    final isSale = type == InvoiceFilterType.sales;
    final isPur = type == InvoiceFilterType.purchases;
    final isRet = type == InvoiceFilterType.returns;

    final badgeColor = isSale
        ? const Color(0xFF10B981)
        : (isPur ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    final badgeLabel = isSale ? 'فاتورة بيع' : (isPur ? 'فاتورة شراء' : 'مرتجع');
    final badgeIcon = isSale
        ? Icons.arrow_downward_rounded
        : (isPur ? Icons.arrow_upward_rounded : Icons.replay_rounded);

    final dateStr =
        DateFormat('yyyy-MM-dd • hh:mm a').format(invoice.createdAt);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showInvoiceDetails(invoice),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // أيقونة نوع الفاتورة
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(badgeIcon, color: badgeColor, size: 20),
            ),
            const SizedBox(width: 12),

            // البيانات الأساسية
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${invoice.invoiceNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${invoice.cashierName ?? "كاشير الصيدلية"}${invoice.customerName != null && invoice.customerName!.isNotEmpty ? " • ${invoice.customerName}" : ""}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),

            // المبلغ وزر السهم
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${format.format(invoice.netAmount)} ر.ي',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    invoice.paymentMethod,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ورقة تفاصيل الفاتورة وقائمة الأصناف الشاملة
class InvoiceDetailsSheet extends StatefulWidget {
  final CloudSale invoice;
  final InvoiceFilterType type;

  const InvoiceDetailsSheet({
    super.key,
    required this.invoice,
    required this.type,
  });

  static void show(
    BuildContext context,
    CloudSale invoice, {
    InvoiceFilterType? type,
  }) {
    final invNum = invoice.invoiceNumber.toUpperCase();
    final resolvedType = type ??
        (invNum.startsWith('PUR') ||
                (invoice.cashierName != null &&
                    invoice.cashierName!.contains('مورد'))
            ? InvoiceFilterType.purchases
            : (invNum.startsWith('RET') ||
                    (invoice.cashierName != null &&
                        invoice.cashierName!.contains('مرتجع')) ||
                    (invoice.customerName != null &&
                        invoice.customerName!.contains('مرتجع'))
                ? InvoiceFilterType.returns
                : InvoiceFilterType.sales));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InvoiceDetailsSheet(
        invoice: invoice,
        type: resolvedType,
      ),
    );
  }

  @override
  State<InvoiceDetailsSheet> createState() => _InvoiceDetailsSheetState();
}

class _InvoiceDetailsSheetState extends State<InvoiceDetailsSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoadingItems = true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    final items = await OwnerApiService.fetchSaleItems(widget.invoice.id);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoadingItems = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final isSale = widget.type == InvoiceFilterType.sales;
    final isPur = widget.type == InvoiceFilterType.purchases;
    final badgeColor = isSale
        ? const Color(0xFF10B981)
        : (isPur ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    final badgeLabel = isSale ? 'فاتورة مبيعات' : (isPur ? 'فاتورة شراء' : 'فاتورة مرتجع');

    final dateStr = DateFormat('yyyy-MM-dd • hh:mm a')
        .format(widget.invoice.createdAt);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.5)),
        ),
        child: Column(
          children: [
            // مؤشر السحب
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ترويسة الفاتورة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '#${widget.invoice.invoiceNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // ملخص الحقول
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildDetailRow('التاريخ والوقت:', dateStr),
                  const SizedBox(height: 6),
                  _buildDetailRow('طريقة الدفع:', widget.invoice.paymentMethod),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                      'المسؤول / الكاشير:', widget.invoice.cashierName ?? 'المناوب'),
                  if (widget.invoice.customerName != null &&
                      widget.invoice.customerName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow(
                        isPur ? 'اسم المورد:' : 'اسم العميل:',
                        widget.invoice.customerName!),
                  ],
                  const Divider(color: Colors.white10, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAmountCol('المبلغ الإجمالي',
                          widget.invoice.totalAmount, currencyFormat),
                      _buildAmountCol('الخصم',
                          widget.invoice.discountAmount, currencyFormat,
                          color: Colors.orangeAccent),
                      _buildAmountCol(
                          'المبلغ الصافي', widget.invoice.netAmount, currencyFormat,
                          color: badgeColor, isBold: true),
                    ],
                  ),
                ],
              ),
            ),

            // عنوان قائمة الأصناف
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الأصناف المشمولة في الفاتورة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_items.length} أصناف',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // محتوى الأصناف
            Expanded(
              child: _isLoadingItems
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.cyanAccent),
                    )
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 40, color: Colors.white24),
                              const SizedBox(height: 8),
                              const Text(
                                'لم يتم إرفاق تفاصيل الأصناف لهذه الفاتورة',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final item = _items[i];
                            final medName = item['medicine_name'] ?? 'صنف';
                            final qty = item['quantity'] ?? 1;
                            final uName = item['unit_name'] ?? 'وحدة';
                            final unitPrice = (item['unit_price'] != null)
                                ? (double.tryParse(item['unit_price'].toString()) ?? 0.0)
                                : 0.0;
                            final totalPrice = (item['total_price'] != null)
                                ? (double.tryParse(item['total_price'].toString()) ?? (qty * unitPrice))
                                : (qty * unitPrice);

                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withOpacity(0.6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.cyanAccent.withOpacity(0.15),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                          color: Colors.cyanAccent, fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          medName,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'الكمية: $qty $uName • سعر الوحدة: ${currencyFormat.format(unitPrice)} ر.ي',
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${currencyFormat.format(totalPrice)} ر.ي',
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAmountCol(String label, double amount, NumberFormat format,
      {Color color = Colors.white, bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          '${format.format(amount)} ر.ي',
          style: TextStyle(
            color: color,
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
