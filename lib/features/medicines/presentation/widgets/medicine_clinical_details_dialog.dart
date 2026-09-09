// نافذة عرض التفاصيل السريرية ودواعي الاستعمال والبدائل للدواء - PharmaOS

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/medicine_clinical_helper.dart';
import '../../domain/entities/medicines_entity.dart';
import '../../domain/repositories/medicines_repository.dart';

class MedicineClinicalDetailsDialog extends StatefulWidget {
  final int medicineId;
  final String? fallbackName;

  const MedicineClinicalDetailsDialog({
    super.key,
    required this.medicineId,
    this.fallbackName,
  });

  static void show(BuildContext context, {required int medicineId, String? fallbackName}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => MedicineClinicalDetailsDialog(
        medicineId: medicineId,
        fallbackName: fallbackName,
      ),
    );
  }

  @override
  State<MedicineClinicalDetailsDialog> createState() => _MedicineClinicalDetailsDialogState();
}

class _MedicineClinicalDetailsDialogState extends State<MedicineClinicalDetailsDialog> {
  MedicineEntity? _medicine;
  bool _isLoading = true;
  List<MedicineEntity> _alternatives = [];

  @override
  void initState() {
    super.initState();
    _loadMedicineDetails();
  }

  Future<void> _loadMedicineDetails() async {
    try {
      final medRepo = sl<MedicinesRepository>();
      final allMeds = await medRepo.getAll();
      final med = allMeds.where((m) => m.id == widget.medicineId).firstOrNull;

      if (med != null) {
        _medicine = med;
        // البحث عن البدائل التي تشترك في نفس الاسم العلمي أو التصنيف
        if (med.nameScientific != null && med.nameScientific!.isNotEmpty) {
          _alternatives = allMeds.where((m) {
            return m.id != med.id &&
                m.nameScientific != null &&
                m.nameScientific!.toLowerCase().contains(med.nameScientific!.toLowerCase());
          }).take(6).toList();
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 650,
          constraints: const BoxConstraints(maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.medication, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _medicine?.nameAr ?? widget.fallbackName ?? 'تفاصيل الدواء',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_medicine?.nameEn != null && _medicine!.nameEn!.isNotEmpty)
                                  Text(
                                    _medicine!.nameEn!,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        shrinkWrap: true,
                        children: [
                          // 1. كارت المعلومات الأساسية
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoTile(
                                        icon: Icons.factory_outlined,
                                        label: 'الشركة المصنعة:',
                                        value: _medicine?.companyName ?? 'غير محدد',
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoTile(
                                        icon: Icons.local_shipping_outlined,
                                        label: 'المورد / الوكيل:',
                                        value: _medicine?.supplierName ?? 'عام',
                                        color: Colors.indigo,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoTile(
                                        icon: Icons.monetization_on_outlined,
                                        label: 'السعر للجمهور:',
                                        value: '${_medicine?.sellingPrice.toStringAsFixed(0) ?? 0} ر.ي',
                                        color: Colors.green,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoTile(
                                        icon: Icons.category_outlined,
                                        label: 'التصنيف الدوائي:',
                                        value: _medicine?.categoryName ?? 'دليل عام',
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoTile(
                                        icon: Icons.inventory_2_outlined,
                                        label: 'التعبئة والشكل الصيدلاني:',
                                        value: _medicine?.reserveField2 ?? 'غير محدد',
                                        color: Colors.orange,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoTile(
                                        icon: Icons.card_giftcard,
                                        label: 'البونص المجاني:',
                                        value: _medicine?.reserveField3 ?? 'لا يوجد',
                                        color: Colors.pink,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 2. المادة الفعالة والتركيب
                          const Text('المادة الفعالة والتركيب العلمي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              (_medicine?.nameScientific != null && _medicine!.nameScientific!.isNotEmpty)
                                  ? _medicine!.nameScientific!
                                  : (_medicine?.nameAr ?? 'تركيبة دوائية علاجية معتمدة'),
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blue.shade900),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 3. دواعي الاستعمال والوصفات الطبية والجرعات ومأمونية الحمل والقلب
                          Builder(
                            builder: (context) {
                              final profile = MedicineClinicalHelper.getFullClinicalProfile(
                                medicineName: _medicine?.nameAr ?? '',
                                scientificName: _medicine?.nameScientific,
                                categoryName: _medicine?.categoryName,
                                rawReserve1: _medicine?.reserveField1,
                                formOrPack: _medicine?.reserveField2,
                              );

                              final clinicalInfo = profile.prescription;
                              final preg = profile.pregnancy;
                              final cardiac = profile.cardiac;
                              final generalWarns = profile.generalWarnings;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- كارت مأمونية الحوامل والبديل الآمن ---
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: preg.isSafe ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: preg.isSafe ? Colors.green.shade300 : Colors.red.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              preg.isSafe ? Icons.pregnant_woman : Icons.warning_amber_rounded,
                                              color: preg.statusColor,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'مأمونية الحمل والرضاعة (Pregnancy & Lactation):',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: preg.isSafe ? Colors.green.shade900 : Colors.red.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          preg.statusLabel,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: preg.statusColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          preg.riskExplanation,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: preg.isSafe ? Colors.green.shade900 : Colors.red.shade900,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (!preg.isSafe) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.green.shade400, width: 1.2),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.verified_user, color: Colors.green, size: 18),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        '💡 البديل الآمن الموصى به للحوامل:',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        preg.safeAlternative,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF065F46),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // --- كارت مأمونية مرضى القلب والضغط والبديل الآمن ---
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cardiac.isSafe ? Colors.teal.shade50 : Colors.deepOrange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: cardiac.isSafe ? Colors.teal.shade300 : Colors.deepOrange.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              cardiac.isSafe ? Icons.favorite : Icons.heart_broken_rounded,
                                              color: cardiac.statusColor,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'مأمونية مرضى القلب والضغط (Cardiac & Hypertension):',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: cardiac.isSafe ? Colors.teal.shade900 : Colors.deepOrange.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          cardiac.statusLabel,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: cardiac.statusColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cardiac.riskExplanation,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cardiac.isSafe ? Colors.teal.shade900 : Colors.deepOrange.shade900,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (!cardiac.isSafe) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.teal.shade400, width: 1.2),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.health_and_safety, color: Colors.teal, size: 18),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        '💡 البديل الآمن الموصى به لمرضى القلب والضغط:',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                          color: Colors.teal,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        cardiac.safeAlternative,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF115E59),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // دواعي الاستعمال
                                  const Row(
                                    children: [
                                      Icon(Icons.medical_information_outlined, size: 18, color: Colors.amber),
                                      SizedBox(width: 6),
                                      Text('دواعي الاستعمال والاستخدامات الطبية المعتمدة:',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.shade200),
                                    ),
                                    child: Text(
                                      clinicalInfo.indications,
                                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900, height: 1.4),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // جرعة البالغين
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 18, color: Colors.teal.shade700),
                                      const SizedBox(width: 6),
                                      Text('الوصفة والجرعة المعتمدة للبالغين (Adult Dosage):',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal.shade900)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.teal.shade200),
                                    ),
                                    child: Text(
                                      clinicalInfo.adultDosage,
                                      style: TextStyle(fontSize: 13, color: Colors.teal.shade900, height: 1.4, fontWeight: FontWeight.w500),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // جرعة الأطفال
                                  Row(
                                    children: [
                                      Icon(Icons.child_care, size: 18, color: Colors.blue.shade700),
                                      const SizedBox(width: 6),
                                      Text('الوصفة والجرعة المعتمدة للأطفال (Pediatric Dosage):',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Text(
                                      clinicalInfo.pediatricDosage,
                                      style: TextStyle(fontSize: 13, color: Colors.blue.shade900, height: 1.4, fontWeight: FontWeight.w500),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // طريقة الاستخدام والإرشادات
                                  Row(
                                    children: [
                                      Icon(Icons.health_and_safety_outlined, size: 18, color: Colors.indigo.shade700),
                                      const SizedBox(width: 6),
                                      Text('طريقة الاستخدام والإرشادات والتحذيرات:',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo.shade900)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.indigo.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          clinicalInfo.instructions,
                                          style: TextStyle(fontSize: 13, color: Colors.indigo.shade900, height: 1.4),
                                        ),
                                        if (generalWarns.warnings.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          const Divider(),
                                          ...generalWarns.warnings.map(
                                            (w) => Padding(
                                              padding: const EdgeInsets.only(top: 3),
                                              child: Text(
                                                w,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          if (_alternatives.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Text('البدائل المتطابقة المتوفرة بالسوق:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _alternatives.map((alt) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.teal.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sync_alt, size: 14, color: Colors.teal),
                                      const SizedBox(width: 6),
                                      Text(alt.nameAr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 6),
                                      Text('(${alt.sellingPrice.toStringAsFixed(0)} ر.ي)',
                                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Footer
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إغلاق التفاصيل'),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ),
      ],
    );
  }
}
