// شاشة سجل العملاء والديون المتكاملة - PharmaOS
// تدعم: كشف حساب العميل، متابعة الديون المستحقة، تسديد الدفعات، إصدار سندات القبض،
// البحث الفوري بكافة الحقول، وتصدير كشف الحساب.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/customers_provider.dart';
import '../controllers/customers_controller.dart';
import '../../domain/entities/customers_entity.dart';
import 'customer_ledger_screen.dart';
import '../../../prescriptions/presentation/providers/prescriptions_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddCustomerDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    String? nameError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.person_add, color: Colors.blue),
                SizedBox(width: 8),
                Text('إضافة عميل جديد'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'اسم العميل (إلزامي)',
                      errorText: nameError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'العنوان / الملاحظات',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () async {
                  final error = CustomersController.validateName(nameController.text);
                  if (error != null) {
                    setDialogState(() => nameError = error);
                    return;
                  }
                  final ok = await ref.read(customersNotifierProvider.notifier).add(
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                      );
                  if (ok && mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة العميل بنجاح ✓'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('حفظ العميل'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCollectDebtDialog(BuildContext context, CustomerBalance balance) async {
    final amountController = TextEditingController(text: balance.remainingDebt > 0 ? balance.remainingDebt.toStringAsFixed(0) : '0');
    final notesController = TextEditingController();
    String? amountError;
    String paymentMethod = 'نقدي';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.price_check, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text('تسديد دين: ${balance.customerName}')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'إجمالي الدين الحالي: ${balance.remainingDebt.toStringAsFixed(0)} ر.ي',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'المبلغ المسدد (ر.ي)',
                      errorText: amountError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'طريقة القبض',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'نقدي', child: Text('نقدي (صندوق الكاشير)')),
                      DropdownMenuItem(value: 'محفظة جيب', child: Text('محفظة جيب (Jeeb)')),
                      DropdownMenuItem(value: 'محفظة جوالي', child: Text('محفظة جوالي (Jawali)')),
                      DropdownMenuItem(value: 'محفظة ون كاش', child: Text('محفظة ون كاش (OneCash)')),
                      DropdownMenuItem(value: 'محفظة الكريمي كاش', child: Text('محفظة الكريمي كاش (Kuraimi)')),
                      DropdownMenuItem(value: 'تحويل بنكي', child: Text('تحويل بنكي / شيك')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات / رقم الحوالة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تأكيد القبض وإصدار السند'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  final enteredAmount = double.tryParse(amountController.text.trim());
                  final error = CustomersController.validatePaymentAmount(
                    amountController.text.trim(),
                    balance.remainingDebt,
                  );
                  if (error != null) {
                    setDialogState(() => amountError = error);
                    return;
                  }
                  if (enteredAmount == null || enteredAmount <= 0) return;

                  final ok = await ref.read(customersNotifierProvider.notifier).recordPayment(
                        customerId: balance.customerId,
                        amount: enteredAmount,
                      );
                  if (ok && mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم تسجيل سند قبض بمبلغ ${enteredAmount.toStringAsFixed(0)} ر.ي للعميل ${balance.customerName} ✓'),
                        backgroundColor: Colors.green,
                      ),
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

  Widget _buildCustomerCard(CustomerEntity customer, CustomerBalance? balance) {
    final debt = balance?.remainingDebt ?? 0.0;
    final hasDebt = debt > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: hasDebt ? Colors.red.shade50 : Colors.blue.shade50,
          child: Icon(
            hasDebt ? Icons.account_balance_wallet_outlined : Icons.person_outline,
            color: hasDebt ? Colors.red : Colors.blue,
          ),
        ),
        title: Row(
          children: [
            Text(
              customer.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            if (customer.phone != null && customer.phone!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  customer.phone!,
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                'الرصيد المدين: ${debt.toStringAsFixed(0)} ر.ي',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasDebt ? Colors.red : Colors.green,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'إجمالي المشتريات الآجلة: ${(balance?.totalInvoiced ?? 0).toStringAsFixed(0)} ر.ي',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasDebt)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.price_check, size: 18),
                label: const Text('تسديد'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                  foregroundColor: Colors.green.shade800,
                ),
                onPressed: () => _showCollectDebtDialog(context, balance!),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.medical_information, color: Colors.blue),
              tooltip: 'الملف الطبي (الوصفات)',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => CustomerMedicalHistoryDialog(customer: customer),
                );
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('كشف الحساب'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerLedgerScreen(customer: customer),
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
    final state = ref.watch(customersNotifierProvider);

    // فلترة بالبحث الفوري
    final q = _searchQuery.trim().toLowerCase();
    final allFiltered = state.items.where((c) {
      final bal = state.balanceFor(c.id);
      return c.name.toLowerCase().contains(q) ||
          (c.phone != null && c.phone!.contains(q)) ||
          bal.remainingDebt.toString().contains(q);
    }).toList();

    final debtorsOnly = allFiltered.where((c) => state.balanceFor(c.id).remainingDebt > 0).toList();

    final totalDebts = state.balances.fold<double>(0, (sum, b) => sum + b.remainingDebt);
    final totalDebtorsCount = state.balances.where((b) => b.remainingDebt > 0).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('سجل العملاء والديون'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(icon: const Icon(Icons.people_outline), text: 'كافة العملاء (${allFiltered.length})'),
              Tab(icon: const Icon(Icons.money_off), text: 'العملاء المدينون ($totalDebtorsCount)'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث البيانات',
              onPressed: () => ref.read(customersNotifierProvider.notifier).loadAll(),
            ),
          ],
        ),
        body: Column(
          children: [
            // بطاقات الإحصائيات العلوية
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
                              const Text('إجمالي الديون المستحقة على العملاء', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              const SizedBox(height: 4),
                              Text(
                                '${totalDebts.toStringAsFixed(0)} ر.ي',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                              const Text('عدد العملاء المدينين', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              const SizedBox(height: 4),
                              Text(
                                '$totalDebtorsCount عميل',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // شريط البحث الشامل
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Colors.blue),
                            hintText: 'ابحث باسم العميل، رقم الهاتف، أو مبلغ الدين...',
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
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text('إضافة عميل'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showAddCustomerDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // قائمة العملاء في التبويبين
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // تبويب كافة العملاء
                        allFiltered.isEmpty
                            ? const Center(child: Text('لا يوجد عملاء مطابقين للبحث'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 8),
                                itemCount: allFiltered.length,
                                itemBuilder: (context, index) {
                                  final customer = allFiltered[index];
                                  final balance = state.balanceFor(customer.id);
                                  return _buildCustomerCard(customer, balance);
                                },
                              ),

                        // تبويب المدينين فقط
                        debtorsOnly.isEmpty
                            ? const Center(child: Text('لا يوجد عملاء مدينون حالياً ✓'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 8),
                                itemCount: debtorsOnly.length,
                                itemBuilder: (context, index) {
                                  final customer = debtorsOnly[index];
                                  final balance = state.balanceFor(customer.id);
                                  return _buildCustomerCard(customer, balance);
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

class CustomerMedicalHistoryDialog extends ConsumerWidget {
  final CustomerEntity customer;
  const CustomerMedicalHistoryDialog({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionsState = ref.watch(prescriptionsProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.medical_information, color: Colors.blue),
            const SizedBox(width: 8),
            Text('الملف الطبي: ${customer.name}'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: prescriptionsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('حدث خطأ: $e')),
            data: (prescriptions) {
              final customerPrescriptions = prescriptions.where((p) => p.customerId == customer.id).toList();
              if (customerPrescriptions.isEmpty) {
                return const Center(child: Text('لا توجد وصفات طبية مسجلة لهذا العميل.'));
              }
              return ListView.builder(
                itemCount: customerPrescriptions.length,
                itemBuilder: (context, index) {
                  final p = customerPrescriptions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.receipt_long, color: Colors.white),
                      ),
                      title: Text(p.diagnosis ?? 'تشخيص غير محدد', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('رقم الوصفة: ${p.prescriptionNumber ?? "-"} | التاريخ: ${p.createdAt?.toIso8601String().split('T')[0] ?? "-"}'),
                      isThreeLine: (p.notes?.isNotEmpty == true),
                      trailing: p.notes?.isNotEmpty == true 
                          ? Tooltip(message: p.notes, child: const Icon(Icons.info_outline, color: Colors.amber)) 
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
