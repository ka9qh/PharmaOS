// نافذة البدائل الذكية العلمية والمخزنية المتوفرة في الصيدلية
import 'package:flutter/material.dart';
import '../../../../core/services/clinical_ai_service.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';

class SmartAlternativesDialog extends StatefulWidget {
  final MedicineEntity targetMedicine;
  final Function(MedicineEntity selectedAlternative)? onAlternativeSelected;

  const SmartAlternativesDialog({
    super.key,
    required this.targetMedicine,
    this.onAlternativeSelected,
  });

  static Future<MedicineEntity?> show(
    BuildContext context, {
    required MedicineEntity targetMedicine,
    Function(MedicineEntity selectedAlternative)? onAlternativeSelected,
  }) {
    return showDialog<MedicineEntity>(
      context: context,
      builder: (ctx) => SmartAlternativesDialog(
        targetMedicine: targetMedicine,
        onAlternativeSelected: onAlternativeSelected,
      ),
    );
  }

  @override
  State<SmartAlternativesDialog> createState() => _SmartAlternativesDialogState();
}

class _SmartAlternativesDialogState extends State<SmartAlternativesDialog> {
  late Future<List<MedicineEntity>> _alternativesFuture;

  @override
  void initState() {
    super.initState();
    _alternativesFuture = ClinicalAiService.findSmartAlternatives(widget.targetMedicine);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Container(
          width: 620,
          constraints: const BoxConstraints(maxHeight: 650),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس النافذة
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.swap_horizontal_circle_rounded, color: Color(0xFF10B981), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'البدائل الدوائية العلمية المتوفرة',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'الأدوية المتوفرة في الصيدلية بنفس المادة الفعالة والتركيب العلمي',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // بطاقة الدواء المطلوب استبداله
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الدواء المراد استبداله: ${widget.targetMedicine.nameAr}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if (widget.targetMedicine.nameScientific != null)
                            Text(
                              'المادة الفعالة: ${widget.targetMedicine.nameScientific}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${widget.targetMedicine.sellingPrice} ر.ي',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // قائمة البدائل المتوفرة
              Expanded(
                child: FutureBuilder<List<MedicineEntity>>(
                  future: _alternativesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد بدائل مسجلة بنفس المادة الفعالة حالياً في الصيدلية',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final alt = list[index];
                        final priceDiff = alt.sellingPrice - widget.targetMedicine.sellingPrice;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.medication_liquid_rounded, color: Color(0xFF10B981), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alt.nameAr,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (alt.nameScientific != null)
                                      Text(
                                        alt.nameScientific!,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'السعر: ${alt.sellingPrice} ر.ي',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        if (priceDiff < 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'أرخص بـ ${priceDiff.abs().toStringAsFixed(0)} ر.ي 🟢',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        else if (priceDiff > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'أعلى بـ ${priceDiff.toStringAsFixed(0)} ر.ي',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFFF59E0B),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('اختيار البديل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () {
                                  widget.onAlternativeSelected?.call(alt);
                                  Navigator.of(context).pop(alt);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('إغلاق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
