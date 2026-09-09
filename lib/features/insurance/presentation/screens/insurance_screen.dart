import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/di/service_locator.dart';
import '../../domain/entities/insurance_entities.dart';
import '../../domain/repositories/insurance_repository.dart';
import '../../../customers/domain/repositories/customers_repository.dart';

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = sl<InsuranceRepository>();
  List<InsuranceCompanyEntity> _companies = [];
  List<InsurancePolicyEntity> _policies = [];
  bool _isLoading = true;

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
    final companies = await _repo.getAllCompanies();
    final policies = await _repo.getAllPolicies();
    setState(() {
      _companies = companies;
      _policies = policies;
      _isLoading = false;
    });
  }

  Future<void> _showAddCompanyDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final coverageCtrl = TextEditingController(text: '0');
    final maxCtrl = TextEditingController(text: '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة شركة تأمين جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة *')),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف')),
                const SizedBox(height: 8),
                TextField(controller: coverageCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'نسبة التغطية الافتراضية %')),
                const SizedBox(height: 8),
                TextField(controller: maxCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الحد الأقصى لكل فاتورة (0 = بلا حد)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await _repo.createCompany(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        defaultCoveragePercent: double.tryParse(coverageCtrl.text) ?? 0,
        maxCoveragePerInvoice: double.tryParse(maxCtrl.text) ?? 0,
      );
      await _loadData();
    }
  }

  Future<void> _showAddPolicyDialog() async {
    final customers = await sl<CustomersRepository>().getAll();
    if (_companies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إضافة شركة تأمين أولاً')),
        );
      }
      return;
    }

    int? selectedCustomerId;
    int? selectedCompanyId = _companies.first.id;
    final policyNumCtrl = TextEditingController();
    final coverageCtrl = TextEditingController(text: _companies.first.defaultCoveragePercent.toString());
    final limitCtrl = TextEditingController(text: '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة بوليصة تأمين'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'العميل *'),
                    items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCustomerId = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedCompanyId,
                    decoration: const InputDecoration(labelText: 'شركة التأمين *'),
                    items: _companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedCompanyId = v;
                        final company = _companies.firstWhere((c) => c.id == v);
                        coverageCtrl.text = company.defaultCoveragePercent.toString();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: policyNumCtrl, decoration: const InputDecoration(labelText: 'رقم البوليصة *')),
                  const SizedBox(height: 8),
                  TextField(controller: coverageCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'نسبة التغطية %')),
                  const SizedBox(height: 8),
                  TextField(controller: limitCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الحد الشهري (0 = بلا حد)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
            ],
          ),
        ),
      ),
    );

    if (result == true && selectedCustomerId != null && selectedCompanyId != null && policyNumCtrl.text.trim().isNotEmpty) {
      await _repo.createPolicy(
        customerId: selectedCustomerId!,
        insuranceCompanyId: selectedCompanyId!,
        policyNumber: policyNumCtrl.text.trim(),
        coveragePercent: double.tryParse(coverageCtrl.text) ?? 0,
        monthlyLimit: double.tryParse(limitCtrl.text) ?? 0,
        startDate: DateTime.now(),
      );
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة التأمين الطبي'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'شركات التأمين', icon: Icon(Icons.business)),
              Tab(text: 'البوالص', icon: Icon(Icons.card_membership)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildCompaniesTab(),
                  _buildPoliciesTab(),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_tabController.index == 0) {
              _showAddCompanyDialog();
            } else {
              _showAddPolicyDialog();
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildCompaniesTab() {
    if (_companies.isEmpty) {
      return const Center(child: Text('لا توجد شركات تأمين مسجلة'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _companies.length,
      itemBuilder: (context, index) {
        final c = _companies[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: c.isActive ? Colors.green.shade100 : Colors.grey.shade200,
              child: Icon(Icons.business, color: c.isActive ? Colors.green : Colors.grey),
            ),
            title: Text(c.name),
            subtitle: Text('التغطية: ${c.defaultCoveragePercent}% | الحد: ${c.maxCoveragePerInvoice > 0 ? '${c.maxCoveragePerInvoice}' : 'بلا حد'}'),
            trailing: Switch(
              value: c.isActive,
              onChanged: (v) async {
                await _repo.updateCompany(c.id, isActive: v);
                _loadData();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPoliciesTab() {
    if (_policies.isEmpty) {
      return const Center(child: Text('لا توجد بوالص تأمين مسجلة'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _policies.length,
      itemBuilder: (context, index) {
        final p = _policies[index];
        return Card(
          color: p.isValid ? null : Colors.red.shade50,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: p.isValid ? Colors.blue.shade100 : Colors.red.shade100,
              child: Icon(Icons.card_membership, color: p.isValid ? Colors.blue : Colors.red),
            ),
            title: Text('${p.customerName} - ${p.insuranceCompanyName}'),
            subtitle: Text(
              'بوليصة: ${p.policyNumber} | تغطية: ${p.coveragePercent}%\n'
              'الحد الشهري: ${p.monthlyLimit > 0 ? '${p.monthlyLimit} (مستهلك: ${p.monthlyUsed})' : 'بلا حد'}\n'
              'من: ${DateFormat('yyyy-MM-dd').format(p.startDate)}'
              '${p.endDate != null ? ' إلى: ${DateFormat('yyyy-MM-dd').format(p.endDate!)}' : ' (مفتوحة)'}',
            ),
            isThreeLine: true,
            trailing: Switch(
              value: p.isActive,
              onChanged: (v) async {
                await _repo.updatePolicy(p.id, isActive: v);
                _loadData();
              },
            ),
          ),
        );
      },
    );
  }
}
