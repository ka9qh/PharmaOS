// شاشة كشف ديون الصيدلية الشاملة (المحاسب الذكي الأقوى) - PharmaOS
// تدعم: ديون فواتير التوريد، والديون والالتزامات العامة الأخرى (إيجار، كهرباء، قروض، صيانة...)،
// والسداد الفوري المباشر مع توثيق السندات وتحديث الصندوق، والبحث الخارق والفلترة بالتاريخ.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:drift/drift.dart' as drift;

import '../providers/pharmacy_debts_provider.dart';
import '../../../purchases/presentation/screens/vendor_payments_screen.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../screens/supplier_ledger_screen.dart';
import '../../domain/entities/suppliers_entity.dart';
import '../../domain/repositories/suppliers_repository.dart';
import '../../../../core/services/partnered_entities_service.dart';

class PharmacyDebtsScreen extends ConsumerStatefulWidget {
  const PharmacyDebtsScreen({super.key});

  @override
  ConsumerState<PharmacyDebtsScreen> createState() => _PharmacyDebtsScreenState();
}

class _PharmacyDebtsScreenState extends ConsumerState<PharmacyDebtsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<ExternalDebtItem> _externalDebts = [];
  bool _isLoadingExternal = true;
  String _dateFilter = 'all'; // all, today, this_week, this_month, custom
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExternalDebts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExternalDebts() async {
    setState(() => _isLoadingExternal = true);
    final list = await PartneredEntitiesService.getExternalDebts();
    if (mounted) {
      setState(() {
        _externalDebts = list;
        _isLoadingExternal = false;
      });
    }
  }

  void _showAddGeneralDebtDialog() {
    final creditorCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final paidCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    DateTime debtDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_card, color: Colors.red),
                SizedBox(width: 8),
                Text('تسجيل دين / التزام مالي جديد على الصيدلية'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: creditorCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'اسم الجهة الدائنة / الشخص الدائن *',
                        hintText: 'مثال: مالك العقار، شركة الكهرباء، بنك، مهندس صيانة...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'سبب وبيان الدين *',
                        hintText: 'مثال: إيجار شهر 8، فاتورة كهرباء مؤجلة، صيانة ديكور...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'المبلغ الإجمالي (ر.ي) *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: paidCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'المدفوع مقدماً إن وجد',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: debtDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => debtDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('تاريخ نشوء الدين / الاستحقاق:'),
                            Text(
                              DateFormat('yyyy-MM-dd').format(debtDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات / شروط السداد',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تسجيل الدين في الحسابات'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  final creditor = creditorCtrl.text.trim();
                  final reason = reasonCtrl.text.trim();
                  final total = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  final paid = double.tryParse(paidCtrl.text.trim()) ?? 0;

                  if (creditor.isEmpty || reason.isEmpty || total <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى استكمال الحقول الإلزامية والمبلغ'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  final newDebt = ExternalDebtItem(
                    id: 'DEBT-${DateTime.now().millisecondsSinceEpoch}',
                    creditorName: creditor,
                    reason: reason,
                    totalAmount: total,
                    paidAmount: paid,
                    date: debtDate,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );

                  await PartneredEntitiesService.addExternalDebt(newDebt);
                  await _loadExternalDebts();

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تسجيل دين "$reason" بمبلغ ${total.toStringAsFixed(0)} ر.ي بنجاح ✓'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayExternalDebtDialog(ExternalDebtItem debt) {
    final amountCtrl = TextEditingController(text: debt.remainingDebt.toStringAsFixed(0));
    final notesCtrl = TextEditingController();
    String method = 'نقدي';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.payment, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text('سداد دين: ${debt.creditorName}')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('البيان: ${debt.reason}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('المتبقي كدين: ${debt.remainingDebt.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ المراد تسديده (ر.ي) *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'طريقة السداد', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'نقدي', child: Text('نقدي (صندوق الصيدلية)')),
                    DropdownMenuItem(value: 'محفظة إلكترونية', child: Text('محفظة إلكترونية')),
                    DropdownMenuItem(value: 'تحويل بنكي', child: Text('تحويل بنكي / شيك')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => method = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات / رقم السند', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (amt <= 0) return;
                  await PartneredEntitiesService.recordPaymentForExternalDebt(
                    debt.id,
                    amt,
                    method,
                    notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  await _loadExternalDebts();
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم توثيق سداد مبلغ ${amt.toStringAsFixed(0)} ر.ي بنجاح ✓'), backgroundColor: Colors.green),
                    );
                  }
                },
                child: const Text('تأكيد السداد'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickSupplierPaymentDialog(BuildContext context, WidgetRef ref, dynamic debt) {
    final amountController = TextEditingController(text: debt.remainingDebt > 0 ? debt.remainingDebt.toStringAsFixed(0) : '0');
    final notesController = TextEditingController();
    String paymentMethod = 'نقدي';
    int? selectedWalletId;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.payment, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text('تسديد دفعة لـ: ${debt.supplierName}')),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي الدين المتبقي للمورد:'),
                          Text(
                            '${debt.remainingDebt.toStringAsFixed(0)} ر.ي',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المراد تسديده الآن (ر.ي) *',
                        border: OutlineInputBorder(),
                        suffixText: 'ر.ي',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('طريقة السداد / نوع التسوية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('نقدي (صندوق الصيدلية)'),
                          selected: paymentMethod == 'نقدي',
                          onSelected: (_) => setState(() => paymentMethod = 'نقدي'),
                        ),
                        ChoiceChip(
                          label: const Text('محفظة إلكترونية'),
                          selected: paymentMethod == 'محفظة',
                          onSelected: (_) => setState(() => paymentMethod = 'محفظة'),
                        ),
                        ChoiceChip(
                          label: const Text('مرتجع أدوية وبضاعة للمورد'),
                          selected: paymentMethod == 'مرتجع',
                          onSelected: (_) => setState(() => paymentMethod = 'مرتجع'),
                        ),
                      ],
                    ),
                    if (paymentMethod == 'مرتجع') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: Colors.purple, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'سيتم خصم قيمة الأدوية المرتجعة من رصيد دين المورد مباشرة بسعر الشراء والتكلفة دون صرف نقدي من الصندوق.',
                                style: TextStyle(fontSize: 12, color: Colors.purple),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (paymentMethod == 'محفظة') ...[
                      const SizedBox(height: 10),
                      Consumer(
                        builder: (context, ref, _) {
                          final walletsAsync = ref.watch(walletsNotifierProvider);
                          return walletsAsync.when(
                            data: (wallets) {
                              if (wallets.isEmpty) return const Text('لا توجد محافظ معرفة');
                              return DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'اختر المحفظة (جيب، جوالي، ون كاش...)',
                                  border: OutlineInputBorder(),
                                ),
                                value: selectedWalletId ?? wallets.first.id,
                                items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                                onChanged: (val) => setState(() => selectedWalletId = val),
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const Text('تعذر تحميل المحافظ'),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: paymentMethod == 'مرتجع'
                            ? 'بيان وتفاصيل الأدوية المرتجعة للمورد *'
                            : 'ملاحظات / رقم السند أو الحوالة',
                        hintText: paymentMethod == 'مرتجع' ? 'مثال: إرجاع 2 باكت بانادول + 1 كرتون قطن تالف' : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                icon: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(paymentMethod == 'مرتجع' ? 'تأكيد خصم المرتجع من الدين' : 'تأكيد السداد وتوثيق الفاتورة'),
                style: FilledButton.styleFrom(backgroundColor: paymentMethod == 'مرتجع' ? Colors.purple.shade700 : Colors.green),
                onPressed: isSaving
                    ? null
                    : () async {
                        final amt = double.tryParse(amountController.text.trim());
                        if (amt == null || amt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى إدخال مبلغ سداد صحيح'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        setState(() => isSaving = true);
                        try {
                          final repo = sl<SuppliersRepository>();
                          final defaultNote = paymentMethod == 'مرتجع'
                              ? 'خصم مقابل مرتجع أدوية وبضاعة للمورد بسعر الشراء'
                              : 'سداد دفعة من حساب المورد';
                          final notes = notesController.text.trim().isNotEmpty
                              ? notesController.text.trim()
                              : defaultNote;

                          final methodLabel = paymentMethod == 'محفظة'
                              ? 'محفظة إلكترونية'
                              : (paymentMethod == 'مرتجع' ? 'مرتجع أدوية' : 'نقدي');

                          await repo.recordVendorPayment(
                            supplierId: debt.supplierId,
                            amount: amt,
                            paymentMethod: methodLabel,
                            notes: notes,
                          );

                          await ref.read(pharmacyDebtsNotifierProvider.notifier).loadDebts();

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(paymentMethod == 'مرتجع'
                                    ? 'تم خصم قيمة المرتجع (${amt.toStringAsFixed(0)} ر.ي) من دين المورد بنجاح ✓'
                                    : 'تم توثيق سداد مبلغ ${amt.toStringAsFixed(0)} ر.ي للمورد بنجاح ✓'),
                                backgroundColor: paymentMethod == 'مرتجع' ? Colors.purple.shade800 : Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('حدث خطأ أثناء السداد: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debtsState = ref.watch(pharmacyDebtsNotifierProvider);

    final q = _searchQuery.trim().toLowerCase();

    // فلترة ديون الموردين
    final filteredSupplierDebts = debtsState.items.where((d) {
      final matchQ = d.supplierName.toLowerCase().contains(q) ||
          d.remainingDebt.toString().contains(q) ||
          d.totalPurchases.toString().contains(q);
      return matchQ;
    }).toList();

    // فلترة الديون العامة
    final filteredExternalDebts = _externalDebts.where((d) {
      final matchQ = d.creditorName.toLowerCase().contains(q) ||
          d.reason.toLowerCase().contains(q) ||
          d.remainingDebt.toString().contains(q);
      return matchQ;
    }).toList();

    final supplierDebtsTotal = debtsState.totalDebts;
    final externalDebtsTotal = _externalDebts.fold<double>(0.0, (sum, d) => sum + d.remainingDebt);
    final grandTotalDebts = supplierDebtsTotal + externalDebtsTotal;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('كشف ديون الصيدلية (المحاسب الذكي الشامل)'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(icon: const Icon(Icons.local_shipping_outlined), text: 'ديون فواتير الموردين (${filteredSupplierDebts.length})'),
              Tab(icon: const Icon(Icons.assignment_outlined), text: 'الديون والالتزامات العامة (${filteredExternalDebts.length})'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'سجل سندات السداد',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorPaymentsScreen()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث الحسابات',
              onPressed: () {
                _loadExternalDebts();
                ref.read(pharmacyDebtsNotifierProvider.notifier).loadDebts();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // بطاقات الإحصائيات المالية العلوية
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('إجمالي كافة ديون والتزامات الصيدلية', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              const SizedBox(height: 4),
                              Text(
                                '${grandTotalDebts.toStringAsFixed(0)} ر.ي',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ديون فواتير التوريد', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              const SizedBox(height: 4),
                              Text(
                                '${supplierDebtsTotal.toStringAsFixed(0)} ر.ي',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الديون والالتزامات العامة', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              const SizedBox(height: 4),
                              Text(
                                '${externalDebtsTotal.toStringAsFixed(0)} ر.ي',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // شريط البحث وأزرار الإضافة والفلترة
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Colors.red),
                            hintText: 'ابحث باسم الدائن، سبب الدين، أو المبلغ...',
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_card),
                        label: const Text('إضافة دين / التزام عام'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showAddGeneralDebtDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // محتوى التبويبين
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // تبويب ديون فواتير الموردين
                  debtsState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredSupplierDebts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_outlined, size: 72, color: Colors.green.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'لا توجد ديون فواتير توريد مستحقة على الصيدلية حالياً ✓\nكافة فواتير الموردين مسددة',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredSupplierDebts.length,
                              itemBuilder: (context, index) {
                                final debt = filteredSupplierDebts[index];
                                final hasDebt = debt.remainingDebt > 0;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 1,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(14),
                                    leading: CircleAvatar(
                                      backgroundColor: hasDebt ? Colors.red.shade50 : Colors.green.shade50,
                                      child: Icon(
                                        hasDebt ? Icons.account_balance_wallet : Icons.check_circle_outline,
                                        color: hasDebt ? Colors.red : Colors.green,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          debt.supplierName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'إجمالي التوريدات: ${debt.totalPurchases.toStringAsFixed(0)} ر.ي',
                                            style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        children: [
                                          Text(
                                            'المسدد: ${debt.totalPaid.toStringAsFixed(0)} ر.ي',
                                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 14),
                                          Text(
                                            'المتبقي كدين: ${debt.remainingDebt.toStringAsFixed(0)} ر.ي',
                                            style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FilledButton.icon(
                                          icon: const Icon(Icons.payment, size: 16),
                                          label: const Text('سداد دفعة'),
                                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                          onPressed: () => _showQuickSupplierPaymentDialog(context, ref, debt),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.receipt_long, size: 16),
                                          label: const Text('كشف الحساب'),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SupplierLedgerScreen(
                                                  supplier: SupplierEntity(
                                                    id: debt.supplierId,
                                                    name: debt.supplierName,
                                                    contactInfo: null,
                                                    notes: null,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                  // تبويب الديون والالتزامات العامة
                  _isLoadingExternal
                      ? const Center(child: CircularProgressIndicator())
                      : filteredExternalDebts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.thumb_up_alt_outlined, size: 72, color: Colors.blue.shade300),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'لا توجد ديون والتزامات عامة مسجلة حالياً ✓',
                                    style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text('اضغط على "إضافة دين / التزام عام" لتسجيل إيجارات أو فواتير مؤجلة أو التزامات أخرى.'),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredExternalDebts.length,
                              itemBuilder: (context, index) {
                                final debt = filteredExternalDebts[index];
                                final hasDebt = debt.remainingDebt > 0;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 1,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(14),
                                    leading: CircleAvatar(
                                      backgroundColor: hasDebt ? Colors.red.shade50 : Colors.green.shade50,
                                      child: Icon(
                                        hasDebt ? Icons.assignment_late_outlined : Icons.check_circle_outline,
                                        color: hasDebt ? Colors.red : Colors.green,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          debt.creditorName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            debt.reason,
                                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        children: [
                                          Text('المبلغ الإجمالي: ${debt.totalAmount.toStringAsFixed(0)} ر.ي'),
                                          const SizedBox(width: 14),
                                          Text(
                                            'المتبقي: ${debt.remainingDebt.toStringAsFixed(0)} ر.ي',
                                            style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 14),
                                          Text(
                                            'التاريخ: ${DateFormat("yyyy-MM-dd").format(debt.date)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: hasDebt
                                        ? FilledButton.icon(
                                            icon: const Icon(Icons.payment, size: 16),
                                            label: const Text('سداد دفعة'),
                                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                            onPressed: () => _showPayExternalDebtDialog(debt),
                                          )
                                        : const Chip(
                                            label: Text('مسدد بالكامل ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                            backgroundColor: Color(0xFFE8F5E9),
                                          ),
                                  ),
                                );
                              },
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
