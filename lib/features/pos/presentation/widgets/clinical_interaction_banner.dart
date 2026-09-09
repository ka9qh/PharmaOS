// شريط التنبيهات السريرية وفاحص التداخلات الدوائية الحي في نقطة البيع
import 'package:flutter/material.dart';
import '../../../../core/services/clinical_ai_service.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';

class ClinicalInteractionBanner extends StatelessWidget {
  final List<MedicineEntity> cartMedicines;

  const ClinicalInteractionBanner({
    super.key,
    required this.cartMedicines,
  });

  @override
  Widget build(BuildContext context) {
    if (cartMedicines.length < 2) {
      return const SizedBox.shrink();
    }

    final interactions = ClinicalAiService.checkInteractions(cartMedicines);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (interactions.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'فحص الأمان السريري الذكي: السلة متوافقة وآمنة',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasSevere = interactions.any((i) => i.severity == InteractionSeverity.severe);
    final bannerColor = hasSevere ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSevere ? Icons.warning_rounded : Icons.info_outline_rounded,
              color: bannerColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSevere
                      ? '⚠️ تحذير سريري حاد: تعارض دوائي مكتشف بالسلة!'
                      : 'ℹ️ تنبيه سريري: تداخل دوائي أو تكرار بالجرعات',
                  style: TextStyle(
                    color: bannerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'عدد التعارضات: ${interactions.length}  |  اضغط لمعاينة التوجيهات الطبية',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: bannerColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.medical_services_rounded, size: 16),
            label: const Text('معاينة التداخلات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _showInteractionDetailsDialog(context, interactions),
          ),
        ],
      ),
    );
  }

  void _showInteractionDetailsDialog(BuildContext context, List<DrugInteractionResult> interactions) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 650),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFFEF4444), size: 26),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تقرير الأمان السريري والتداخلات الدوائية',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'تم رصد التداخلات التالية بين الأدوية في سلة البيع الحالية',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: interactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = interactions[index];
                      final isSevere = item.severity == InteractionSeverity.severe;
                      final cardColor = isSevere ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardColor.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isSevere ? 'خطر شديد 🔴' : 'تحذير متوسط 🟡',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cardColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // الأدوية المتعارضة
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.medicineA.nameAr,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        if (item.medicineA.nameScientific != null)
                                          Text(
                                            item.medicineA.nameScientific!,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.swap_horiz_rounded, color: Colors.grey),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.medicineB.nameAr,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        if (item.medicineB.nameScientific != null)
                                          Text(
                                            item.medicineB.nameScientific!,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.descriptionAr,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_rounded, color: Color(0xFF3B82F6), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'الإجراء الموصى به: ${item.recommendationAr}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('فهمت، إغلاق التقرير'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
