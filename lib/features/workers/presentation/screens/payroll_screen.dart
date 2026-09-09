import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/entities/payroll_entities.dart';
import '../../domain/repositories/payroll_repository.dart';
import '../../../workers/domain/repositories/workers_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = sl<PayrollRepository>();
  List<PayrollEntity> _payrolls = [];
  List<WorkerAdvanceEntity> _advances = [];
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final payrolls = await _repo.getPayrollForMonth(_selectedMonth, _selectedYear);
    final advances = await _repo.getAllAdvances();
    setState(() {
      _payrolls = payrolls;
      _advances = advances;
      _isLoading = false;
    });
  }

  Future<void> _generatePayrolls() async {
    final workers = await sl<WorkersRepository>().getAllWorkers();
    final activeWorkers = workers.where((w) => w.isActive).toList();
    
    if (activeWorkers.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد موظفون نشطون')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('توليد كشوف الرواتب'),
          content: Text('سيتم توليد كشوف رواتب لـ ${activeWorkers.length} موظف لشهر $_selectedMonth/$_selectedYear\nهل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('توليد')),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    int generated = 0;
    for (final worker in activeWorkers) {
      try {
        await _repo.generatePayroll(workerId: worker.id ?? 0 ?? 0, month: _selectedMonth, year: _selectedYear);
        generated++;
      } catch (e) {
        // كشف موجود مسبقاً لهذا الموظف - تجاوز
      }
    }
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم توليد $generated كشف راتب')));
    }
  }

  Future<void> _payPayroll(PayrollEntity payroll) async {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.user?.id;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('صرف راتب ${payroll.workerName}'),
          content: Text('صافي الراتب: ${payroll.netSalary.toStringAsFixed(0)} ريال\nهل تريد الصرف الآن؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('صرف')),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.payPayroll(payrollId: payroll.id, paymentMethod: 'نقدي', paidBy: userId ?? 1);
      await _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم صرف الراتب بنجاح ✅')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showAddAdvanceDialog() async {
    final workers = await sl<WorkersRepository>().getAllWorkers();
    final activeWorkers = workers.where((w) => w.isActive).toList();
    int? selectedWorkerId;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل سلفة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'الموظف *'),
                  items: activeWorkers.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                  onChanged: (v) => selectedWorkerId = v,
                ),
                const SizedBox(height: 8),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'المبلغ *')),
                const SizedBox(height: 8),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'السبب')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل')),
          ],
        ),
      ),
    );

    if (result == true && selectedWorkerId != null) {
      final amount = double.tryParse(amountCtrl.text) ?? 0;
      if (amount <= 0) return;
      final authState = ref.read(authNotifierProvider);
      await _repo.createAdvance(
        workerId: selectedWorkerId!,
        amount: amount,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
        approvedBy: authState.user?.id,
      );
      await _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل السلفة بنجاح ✅')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('شؤون الموظفين - الرواتب والسلف'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'كشوف الرواتب', icon: Icon(Icons.receipt_long)),
              Tab(text: 'السلف', icon: Icon(Icons.money_off)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildPayrollTab(),
                  _buildAdvancesTab(),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_tabController.index == 0) {
              _generatePayrolls();
            } else {
              _showAddAdvanceDialog();
            }
          },
          tooltip: 'إضافة',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildPayrollTab() {
    return Column(
      children: [
        // شريط اختيار الشهر
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
                setState(() {
                  _selectedMonth--;
                  if (_selectedMonth < 1) { _selectedMonth = 12; _selectedYear--; }
                });
                _loadData();
              }),
              Expanded(
                child: Text(
                  'شهر $_selectedMonth / $_selectedYear',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
                setState(() {
                  _selectedMonth++;
                  if (_selectedMonth > 12) { _selectedMonth = 1; _selectedYear++; }
                });
                _loadData();
              }),
            ],
          ),
        ),
        if (_payrolls.isEmpty)
          const Expanded(child: Center(child: Text('لا توجد كشوف لهذا الشهر\nاضغط + لتوليد كشوف الرواتب', textAlign: TextAlign.center)))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _payrolls.length,
              itemBuilder: (context, index) {
                final p = _payrolls[index];
                return Card(
                  color: p.isPaid ? Colors.green.shade50 : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.isPaid ? Colors.green : Colors.orange,
                      child: Icon(p.isPaid ? Icons.check : Icons.schedule, color: Colors.white),
                    ),
                    title: Text(p.workerName),
                    subtitle: Text(
                      'أساسي: ${p.baseSalary.toStringAsFixed(0)} | بدلات: ${p.totalAllowances.toStringAsFixed(0)} | خصومات: ${p.totalDeductions.toStringAsFixed(0)}\n'
                      'حضور: ${p.daysWorked.toInt()} يوم | غياب: ${p.daysAbsent.toInt()} يوم | سلف مخصومة: ${p.totalAdvancesDeducted.toStringAsFixed(0)}\n'
                      'صافي الراتب: ${p.netSalary.toStringAsFixed(0)} ريال',
                    ),
                    isThreeLine: true,
                    trailing: p.isPaid
                        ? const Chip(label: Text('مصروف', style: TextStyle(color: Colors.green)), avatar: Icon(Icons.check_circle, color: Colors.green, size: 18))
                        : FilledButton(
                            onPressed: () => _payPayroll(p),
                            child: const Text('صرف'),
                          ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAdvancesTab() {
    if (_advances.isEmpty) {
      return const Center(child: Text('لا توجد سلف مسجلة'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _advances.length,
      itemBuilder: (context, index) {
        final a = _advances[index];
        return Card(
          color: a.isFullyDeducted ? Colors.grey.shade100 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: a.isFullyDeducted ? Colors.grey : Colors.red.shade100,
              child: Icon(Icons.money_off, color: a.isFullyDeducted ? Colors.grey : Colors.red),
            ),
            title: Text('${a.workerName} - ${a.amount.toStringAsFixed(0)} ريال'),
            subtitle: Text(
              'المتبقي: ${a.remainingAmount.toStringAsFixed(0)} ريال'
              '${a.reason != null ? ' | السبب: ${a.reason}' : ''}'
              '${a.isFullyDeducted ? '\n✅ تم خصمها بالكامل' : ''}',
            ),
            isThreeLine: a.isFullyDeducted || a.reason != null,
          ),
        );
      },
    );
  }
}
