// شاشة إدارة الأطباء والعيادات - PharmaOS
// تدعم: البحث الفوري، إضافة وتعديل وحذف الأطباء، زر الرجوع، وعرض كافة التفاصيل

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../providers/doctors_provider.dart';
import '../../../../core/database/app_database.dart';

class DoctorsScreen extends ConsumerStatefulWidget {
  const DoctorsScreen({super.key});

  @override
  ConsumerState<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends ConsumerState<DoctorsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(doctorsProvider.notifier).loadDoctors();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDoctorDialog([DoctorRow? doctor]) {
    final nameCtrl = TextEditingController(text: doctor?.name);
    final specialtyCtrl = TextEditingController(text: doctor?.specialty);
    final phoneCtrl = TextEditingController(text: doctor?.phone);
    final addressCtrl = TextEditingController(text: doctor?.clinicAddress);
    String? nameError;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  doctor == null ? Icons.person_add : Icons.edit,
                  color: Colors.teal,
                ),
                const SizedBox(width: 8),
                Text(doctor == null ? 'إضافة طبيب جديد' : 'تعديل بيانات الطبيب'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'اسم الطبيب *',
                      errorText: nameError,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    onChanged: (val) {
                      if (nameError != null && val.trim().isNotEmpty) {
                        setDialogState(() => nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: specialtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'التخصص (مثال: باطنية، أطفال، عظام)',
                      border: OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.medical_services_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف / الجوال',
                      border: OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان العيادة / المشفى',
                      border: OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on_outlined),
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
                icon: const Icon(Icons.check),
                label: const Text('حفظ'),
                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    setDialogState(() => nameError = 'يرجى إدخال اسم الطبيب');
                    return;
                  }
                  if (doctor == null) {
                    ref.read(doctorsProvider.notifier).addDoctor(
                          DoctorsCompanion.insert(
                            name: name,
                            specialty: drift.Value(specialtyCtrl.text.trim().isEmpty ? null : specialtyCtrl.text.trim()),
                            phone: drift.Value(phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim()),
                            clinicAddress: drift.Value(addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim()),
                          ),
                        );
                  } else {
                    ref.read(doctorsProvider.notifier).updateDoctor(
                          doctor.copyWith(
                            name: name,
                            specialty: drift.Value(specialtyCtrl.text.trim().isEmpty ? null : specialtyCtrl.text.trim()),
                            phone: drift.Value(phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim()),
                            clinicAddress: drift.Value(addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim()),
                            updatedAt: DateTime.now(),
                          ),
                        );
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(doctor == null ? 'تمت إضافة الطبيب بنجاح ✓' : 'تم تعديل بيانات الطبيب بنجاح ✓'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(DoctorRow doctor) {
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
              Text('حذف طبيب'),
            ],
          ),
          content: Text('هل أنت متأكد من حذف الطبيب "${doctor.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                ref.read(doctorsProvider.notifier).deleteDoctor(doctor.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف الطبيب بنجاح ✓'), backgroundColor: Colors.red),
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
    final state = ref.watch(doctorsProvider);

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
              Icon(Icons.medical_services_outlined, color: Colors.teal),
              SizedBox(width: 8),
              Text('دليل الأطباء والعيادات'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث القائمة',
              onPressed: () {
                ref.read(doctorsProvider.notifier).loadDoctors(searchQuery: _searchQuery.isEmpty ? null : _searchQuery);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showDoctorDialog(),
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة طبيب'),
          backgroundColor: Colors.teal,
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
                  labelText: 'بحث بالاسم، التخصص، أو الهاتف...',
                  prefixIcon: const Icon(Icons.search, color: Colors.teal),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            ref.read(doctorsProvider.notifier).loadDoctors();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                  ref.read(doctorsProvider.notifier).loadDoctors(searchQuery: val.trim().isEmpty ? null : val.trim());
                },
              ),
            ),

            // قائمة الأطباء
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('حدث خطأ في تحميل الأطباء: $e'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        onPressed: () => ref.read(doctorsProvider.notifier).loadDoctors(),
                      ),
                    ],
                  ),
                ),
                data: (doctors) {
                  if (doctors.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'لم يتم إضافة أي طبيب بعد.' : 'لا توجد نتائج مطابقة لبحثك.',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          if (_searchQuery.isEmpty)
                            FilledButton.icon(
                              icon: const Icon(Icons.person_add),
                              label: const Text('إضافة أول طبيب الآن'),
                              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                              onPressed: () => _showDoctorDialog(),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.teal.shade50,
                            child: const Icon(Icons.medical_services, color: Colors.teal),
                          ),
                          title: Text(
                            doctor.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    doctor.specialty?.isNotEmpty == true ? doctor.specialty! : 'تخصص عام',
                                    style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                                  ),
                                  if (doctor.phone?.isNotEmpty == true) ...[
                                    const SizedBox(width: 12),
                                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(doctor.phone!, style: const TextStyle(fontSize: 12)),
                                  ],
                                ],
                              ),
                              if (doctor.clinicAddress?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        doctor.clinicAddress!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'تعديل',
                                onPressed: () => _showDoctorDialog(doctor),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'حذف',
                                onPressed: () => _confirmDelete(doctor),
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
