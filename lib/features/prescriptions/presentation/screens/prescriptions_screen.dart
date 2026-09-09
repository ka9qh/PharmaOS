// شاشة إدارة الوصفات الطبية وملفات المرضى - PharmaOS
// تدعم: البحث الفوري، إضافة وتعديل وحذف الوصفات، زر الرجوع، ربط المريض والطبيب والتشخيص

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../providers/prescriptions_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../doctors/presentation/providers/doctors_provider.dart';
import '../../../customers/presentation/providers/customers_provider.dart';
import '../../../customers/domain/entities/customers_entity.dart';
import '../../../../core/widgets/searchable_entity_picker.dart';

class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  ConsumerState<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(prescriptionsProvider.notifier).loadPrescriptions();
      ref.read(doctorsProvider.notifier).loadDoctors();
      ref.read(customersNotifierProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPrescriptionDialog([PrescriptionRow? prescription]) {
    final numberCtrl = TextEditingController(text: prescription?.prescriptionNumber);
    final diagnosisCtrl = TextEditingController(text: prescription?.diagnosis);
    final notesCtrl = TextEditingController(text: prescription?.notes);

    int? selectedDoctorId = prescription?.doctorId;
    int? selectedCustomerId = prescription?.customerId;
    String? formError;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    prescription == null ? Icons.post_add : Icons.edit_note,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(prescription == null ? 'إضافة وصفة طبية جديدة' : 'تعديل بيانات الوصفة'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (formError != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            formError!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),

                      TextField(
                        controller: numberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'رقم الوصفة (اختياري / تلقائي)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // اختيار العميل (المريض)
                      Consumer(
                        builder: (context, ref, _) {
                          final customersState = ref.watch(customersNotifierProvider);
                          final customers = customersState.items;
                          final currentCustomer = customers.where((c) => c.id == selectedCustomerId).firstOrNull;

                          return InkWell(
                            onTap: () async {
                              final selected = await showSearchableEntityPicker<CustomerEntity>(
                                context: context,
                                items: customers,
                                title: 'اختر العميل (المريض)',
                                searchHint: 'ابحث عن العميل بالاسم أو الهاتف...',
                                itemLabelBuilder: (c) => '${c.name} ${c.phone != null ? "(${c.phone})" : ""}',
                                searchFilter: (c, query) =>
                                    c.name.toLowerCase().contains(query.toLowerCase()) ||
                                    (c.phone ?? '').contains(query),
                              );
                              if (selected != null) {
                                setDialogState(() => selectedCustomerId = selected.id);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'المريض / العميل',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.person_outline),
                                suffixIcon: selectedCustomerId != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setDialogState(() => selectedCustomerId = null),
                                      )
                                    : const Icon(Icons.arrow_drop_down),
                              ),
                              child: Text(
                                currentCustomer?.name ?? 'اضغط لاختيار المريض...',
                                style: TextStyle(
                                  color: currentCustomer != null ? Colors.black87 : Colors.grey.shade600,
                                  fontWeight: currentCustomer != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // اختيار الطبيب المعالج
                      Consumer(
                        builder: (context, ref, _) {
                          final doctorsState = ref.watch(doctorsProvider);
                          final doctors = doctorsState.value ?? [];
                          final currentDoctor = doctors.where((d) => d.id == selectedDoctorId).firstOrNull;

                          return InkWell(
                            onTap: () async {
                              final selected = await showSearchableEntityPicker<DoctorRow>(
                                context: context,
                                items: doctors,
                                title: 'اختر الطبيب المعالج',
                                searchHint: 'ابحث عن الطبيب بالاسم أو التخصص...',
                                itemLabelBuilder: (d) => '${d.name} (${d.specialty ?? "تخصص عام"})',
                                searchFilter: (d, query) =>
                                    d.name.toLowerCase().contains(query.toLowerCase()) ||
                                    (d.specialty ?? '').toLowerCase().contains(query.toLowerCase()),
                              );
                              if (selected != null) {
                                setDialogState(() => selectedDoctorId = selected.id);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'الطبيب المعالج',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.medical_services_outlined),
                                suffixIcon: selectedDoctorId != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setDialogState(() => selectedDoctorId = null),
                                      )
                                    : const Icon(Icons.arrow_drop_down),
                              ),
                              child: Text(
                                currentDoctor != null
                                    ? '${currentDoctor.name} (${currentDoctor.specialty ?? "تخصص عام"})'
                                    : 'اضغط لاختيار الطبيب...',
                                style: TextStyle(
                                  color: currentDoctor != null ? Colors.black87 : Colors.grey.shade600,
                                  fontWeight: currentDoctor != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: diagnosisCtrl,
                        decoration: const InputDecoration(
                          labelText: 'التشخيص الطبي *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.health_and_safety_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات الأدوية والجرعات',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('حفظ'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: () {
                    final diagnosis = diagnosisCtrl.text.trim();
                    if (diagnosis.isEmpty && numberCtrl.text.trim().isEmpty) {
                      setDialogState(() => formError = 'يرجى إدخال رقم الوصفة أو التشخيص الطبي');
                      return;
                    }

                    if (prescription == null) {
                      ref.read(prescriptionsProvider.notifier).addPrescription(
                            PrescriptionsCompanion.insert(
                              prescriptionNumber: drift.Value(numberCtrl.text.trim().isEmpty ? null : numberCtrl.text.trim()),
                              diagnosis: drift.Value(diagnosis.isEmpty ? null : diagnosis),
                              notes: drift.Value(notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim()),
                              customerId: drift.Value(selectedCustomerId),
                              doctorId: drift.Value(selectedDoctorId),
                              issueDate: drift.Value(DateTime.now()),
                            ),
                          );
                    } else {
                      ref.read(prescriptionsProvider.notifier).updatePrescription(
                            prescription.copyWith(
                              prescriptionNumber: drift.Value(numberCtrl.text.trim().isEmpty ? null : numberCtrl.text.trim()),
                              diagnosis: drift.Value(diagnosis.isEmpty ? null : diagnosis),
                              notes: drift.Value(notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim()),
                              customerId: drift.Value(selectedCustomerId),
                              doctorId: drift.Value(selectedDoctorId),
                              updatedAt: DateTime.now(),
                            ),
                          );
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(prescription == null ? 'تمت إضافة الوصفة الطبية بنجاح ✓' : 'تم تعديل الوصفة بنجاح ✓'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(PrescriptionRow prescription) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('حذف وصفة طبية'),
            ],
          ),
          content: Text('هل أنت متأكد من حذف الوصفة "${prescription.prescriptionNumber ?? prescription.diagnosis ?? prescription.id}"؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                ref.read(prescriptionsProvider.notifier).deletePrescription(prescription.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف الوصفة الطبية بنجاح ✓'), backgroundColor: Colors.red),
                );
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prescriptionsProvider);
    final customersState = ref.watch(customersNotifierProvider);
    final doctorsState = ref.watch(doctorsProvider);

    final customersMap = {for (var c in customersState.items) c.id: c.name};
    final doctorsMap = {for (var d in (doctorsState.value ?? <DoctorRow>[])) d.id: d};

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'رجوع للرئيسية',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go('/dashboard');
              }
            },
          ),
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.green),
              SizedBox(width: 8),
              Text('الوصفات الطبية وملفات المرضى'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث القائمة',
              onPressed: () {
                ref.read(prescriptionsProvider.notifier).loadPrescriptions(
                      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
                    );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showPrescriptionDialog(),
          icon: const Icon(Icons.add_task),
          label: const Text('إضافة وصفة'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // شريط البحث المباشر
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'بحث برقم الوصفة، التشخيص، اسم المريض أو الطبيب...',
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            ref.read(prescriptionsProvider.notifier).loadPrescriptions();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                  ref.read(prescriptionsProvider.notifier).loadPrescriptions(
                        searchQuery: val.trim().isEmpty ? null : val.trim(),
                      );
                },
              ),
            ),

            // قائمة الوصفات الطبية
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('حدث خطأ في تحميل الوصفات: $e'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        onPressed: () => ref.read(prescriptionsProvider.notifier).loadPrescriptions(),
                      ),
                    ],
                  ),
                ),
                data: (prescriptions) {
                  // تصفية إضافية تشمل اسم المريض أو الطبيب
                  final filtered = _searchQuery.isEmpty
                      ? prescriptions
                      : prescriptions.where((p) {
                          final q = _searchQuery.toLowerCase();
                          final patientName = p.customerId != null ? (customersMap[p.customerId] ?? '').toLowerCase() : '';
                          final doctor = p.doctorId != null ? doctorsMap[p.doctorId] : null;
                          final doctorName = doctor != null ? doctor.name.toLowerCase() : '';
                          final num = (p.prescriptionNumber ?? '').toLowerCase();
                          final diag = (p.diagnosis ?? '').toLowerCase();
                          final notes = (p.notes ?? '').toLowerCase();

                          return num.contains(q) ||
                              diag.contains(q) ||
                              notes.contains(q) ||
                              patientName.contains(q) ||
                              doctorName.contains(q);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'لا توجد وصفات طبية مسجلة حتى الآن.' : 'لا توجد نتائج مطابقة لبحثك.',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          if (_searchQuery.isEmpty)
                            FilledButton.icon(
                              icon: const Icon(Icons.add_task),
                              label: const Text('تسجيل أول وصفة الآن'),
                              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                              onPressed: () => _showPrescriptionDialog(),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final pre = filtered[index];
                      final customerName = pre.customerId != null ? (customersMap[pre.customerId] ?? 'عميل #${pre.customerId}') : 'بدون عميل محدد';
                      final doctor = pre.doctorId != null ? doctorsMap[pre.doctorId] : null;
                      final dateStr = pre.createdAt != null ? '${pre.createdAt!.year}-${pre.createdAt!.month.toString().padLeft(2, '0')}-${pre.createdAt!.day.toString().padLeft(2, '0')}' : '-';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.green.shade50,
                                child: const Icon(Icons.receipt_long, color: Colors.green),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          pre.diagnosis?.isNotEmpty == true ? pre.diagnosis! : 'تشخيص غير محدد',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        if (pre.prescriptionNumber?.isNotEmpty == true) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'رقم #${pre.prescriptionNumber}',
                                              style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              'المريض: $customerName',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                        if (doctor != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.medical_services_outlined, size: 14, color: Colors.teal.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                'الطبيب: ${doctor.name} (${doctor.specialty ?? "عام"})',
                                                style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
                                              ),
                                            ],
                                          ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              'التاريخ: $dateStr',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (pre.notes?.isNotEmpty == true) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.amber.shade200),
                                        ),
                                        child: Text(
                                          'الأدوية والجرعات: ${pre.notes}',
                                          style: TextStyle(fontSize: 12, color: Colors.brown.shade800),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'تعديل',
                                    onPressed: () => _showPrescriptionDialog(pre),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'حذف',
                                    onPressed: () => _confirmDelete(pre),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
