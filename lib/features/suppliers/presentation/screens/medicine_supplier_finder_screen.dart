// شاشة محرك البحث الذكي عن مورد الدواء - PharmaOS
// تتيح للصيدلي كتابة اسم أي علاج للوصول فورياً إلى المورد والوكيل المسؤول
// مع إمكانية التواصل المباشر عبر واتساب بطلب جاهز أو الاتصال الهاتفي.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../medicines/presentation/providers/medicines_provider.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../providers/suppliers_provider.dart';
import '../../domain/entities/suppliers_entity.dart';
import '../../../../core/services/supplier_catalog_mapping_service.dart';
import '../../../../core/services/partnered_entities_service.dart';
import '../../../../core/services/medicine_translation_service.dart';
import '../../../purchases/presentation/screens/purchase_form_screen.dart';

class MedicineSupplierFinderScreen extends ConsumerStatefulWidget {
  final MedicineEntity? initialMedicine;
  const MedicineSupplierFinderScreen({super.key, this.initialMedicine});

  @override
  ConsumerState<MedicineSupplierFinderScreen> createState() => _MedicineSupplierFinderScreenState();
}

class _MedicineSupplierFinderScreenState extends ConsumerState<MedicineSupplierFinderScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  MedicineEntity? _selectedMedicine;
  Map<int, SupplierDistributionProfile> _profiles = {};
  List<int> _partneredSupplierIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialMedicine != null) {
      _selectedMedicine = widget.initialMedicine;
      _searchController.text = widget.initialMedicine!.nameAr;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final profiles = await SupplierCatalogMappingService.getAllProfiles();
    final partnered = await PartneredEntitiesService.getPartneredSupplierIds();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _partneredSupplierIds = partnered;
        _isLoading = false;
      });
    }
  }

  List<SupplierEntity> _findMatchingSuppliers(MedicineEntity medicine, List<SupplierEntity> allSuppliers) {
    final companyName = (medicine.companyName ?? '').trim().toLowerCase();
    final categoryName = (medicine.categoryName ?? '').trim().toLowerCase();
    final medName = medicine.nameAr.toLowerCase();

    final matched = <SupplierEntity>[];

    for (final s in allSuppliers) {
      final profile = _profiles[s.id];
      bool isMatch = false;

      // 1. فحص ملف التوزيع المخصص
      if (profile != null) {
        for (final comp in profile.representedCompanies) {
          if (comp.toLowerCase().contains(companyName) || (companyName.isNotEmpty && companyName.contains(comp.toLowerCase()))) {
            isMatch = true;
            break;
          }
        }
        if (!isMatch) {
          for (final cat in profile.distributedCategories) {
            if (cat.toLowerCase().contains(categoryName) || cat.toLowerCase().contains(medName)) {
              isMatch = true;
              break;
            }
          }
        }
      }

      // 2. مطابقة ذكية مع اسم المورد / الوكالة
      if (!isMatch && companyName.isNotEmpty) {
        final supName = s.name.toLowerCase();
        if (supName.contains(companyName) || companyName.contains(supName)) {
          isMatch = true;
        }
      }

      if (isMatch) {
        matched.add(s);
      }
    }

    // إذا لم نجد تطابقاً خاصاً، نعرض الموردين المتعامل معهم كمقترح أول
    if (matched.isEmpty) {
      final partneredList = allSuppliers.where((s) => _partneredSupplierIds.contains(s.id)).toList();
      return partneredList.isNotEmpty ? partneredList : allSuppliers.take(5).toList();
    }

    return matched;
  }

  @override
  Widget build(BuildContext context) {
    final medicinesState = ref.watch(medicinesNotifierProvider);
    final suppliersState = ref.watch(suppliersNotifierProvider);

    final q = _searchQuery.trim().toLowerCase();
    final filteredMedicines = q.isEmpty
        ? <MedicineEntity>[]
        : medicinesState.items.where((m) {
            final nameAr = m.nameAr.toLowerCase();
            final nameEn = (m.nameEn ?? '').toLowerCase();
            final comp = (m.companyName ?? '').toLowerCase();
            return nameAr.contains(q) || nameEn.contains(q) || comp.contains(q);
          }).take(20).toList();

    final matchingSuppliers = _selectedMedicine != null
        ? _findMatchingSuppliers(_selectedMedicine!, suppliersState.items)
        : <SupplierEntity>[];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('محرك البحث الذكي عن مورد الدواء'),
        ),
        body: Column(
          children: [
            // شريط البحث الذكي عن الدواء
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ابحث عن أي دواء أو مستحضر لمعرفة المورد والوكيل المسؤول والتواصل معه فوراً:',
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    autofocus: _selectedMedicine == null,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      hintText: 'اكتب اسم الدواء بالعربي أو الإنجليزي أو الشركة المصنعة...',
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedMedicine = null;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        if (_selectedMedicine != null && _selectedMedicine!.nameAr != val) {
                          _selectedMedicine = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            // قائمة نتائج البحث عن الدواء أو تفاصيل الدواء المختار
            Expanded(
              child: _selectedMedicine == null
                  ? (q.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.medication_liquid_outlined, size: 72, color: Colors.teal.shade300),
                              const SizedBox(height: 14),
                              const Text(
                                'محرك مطابقة الموردين والشركات جاهز',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'اكتب اسم أي دواء في شريط البحث أعلاه لمعرفة المورد والاتصال به أو مراسلته واتساب بنقرة واحدة.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : filteredMedicines.isEmpty
                          ? const Center(child: Text('لا توجد أدوية مطابقة لبحثك'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredMedicines.length,
                              itemBuilder: (context, index) {
                                final med = filteredMedicines[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.teal.shade50,
                                      child: const Icon(Icons.medication, color: Colors.teal),
                                    ),
                                    title: Text(med.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      '${med.nameEn != null ? "${med.nameEn} | " : ""}الشركة: ${med.companyName ?? "غير محدد"}',
                                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                    ),
                                    trailing: FilledButton.tonal(
                                      child: const Text('كشف الموردين'),
                                      onPressed: () {
                                        setState(() {
                                          _selectedMedicine = med;
                                          _searchController.text = med.nameAr;
                                          _searchQuery = '';
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // بطاقة تفاصيل الدواء المختار
                          Card(
                            color: Colors.teal.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.teal.shade200)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.medication, size: 36, color: Colors.teal),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedMedicine!.nameAr,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                                        ),
                                        if (_selectedMedicine!.nameEn != null && _selectedMedicine!.nameEn!.isNotEmpty)
                                          Text(_selectedMedicine!.nameEn!, style: TextStyle(fontSize: 13, color: Colors.teal.shade900)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'الشركة المصنعة: ${_selectedMedicine!.companyName ?? "غير محدد"} | التصنيف: ${_selectedMedicine!.categoryName ?? "عام"}',
                                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.change_circle_outlined),
                                    label: const Text('تغيير الدواء'),
                                    onPressed: () {
                                      setState(() {
                                        _selectedMedicine = null;
                                        _searchController.clear();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // عنوان قائمة الموردين المطابقين
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الموردون والوكلاء المسؤولون عن هذا الدواء (${matchingSuppliers.length}):',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              FilledButton.icon(
                                icon: const Icon(Icons.add_shopping_cart, size: 16),
                                label: const Text('إنشاء فاتورة توريد'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseFormScreen()));
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // بطاقات الموردين
                          ...matchingSuppliers.map((supplier) {
                            final profile = _profiles[supplier.id];
                            final phone = supplier.contactInfo ?? profile?.phone ?? profile?.whatsappNumber;
                            final isPartner = _partneredSupplierIds.contains(supplier.id);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: isPartner ? Colors.teal.shade50 : Colors.grey.shade100,
                                          child: Icon(Icons.business, color: isPartner ? Colors.teal : Colors.blueGrey),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                  const SizedBox(width: 8),
                                                  if (isPartner)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                                                      child: const Text('مورد متعامل معه ✓', style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'الهاتف / التواصل: ${phone ?? "غير مسجل"}',
                                                style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // زر الاتصال
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.call, color: Colors.blue),
                                          label: const Text('اتصال هاتفي', style: TextStyle(color: Colors.blue)),
                                          onPressed: phone != null && phone.isNotEmpty
                                              ? () => SupplierCatalogMappingService.launchPhoneCall(phone)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),

                                        // زر المراسلة عبر واتساب
                                        FilledButton.icon(
                                          icon: const Icon(Icons.chat, color: Colors.white),
                                          label: const Text('طلب العلاج عبر واتساب'),
                                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                                          onPressed: phone != null && phone.isNotEmpty
                                              ? () => SupplierCatalogMappingService.launchWhatsAppOrder(
                                                    rawPhone: phone,
                                                    medicineName: _selectedMedicine!.nameAr,
                                                    companyName: _selectedMedicine!.companyName,
                                                  )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
