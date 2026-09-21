// نافذة البدائل الذكية العلمية والمخزنية المتوفرة في الصيدلية - PharmaOS
import 'package:flutter/material.dart';
import '../../../../core/services/clinical_ai_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../inventory/domain/repositories/inventory_repository.dart';

class AlternativeDrugItem {
  final MedicineEntity medicine;
  final int availableStock;
  final String stockBreakdown;
  final String latestExpiryStr;
  final bool isAvailable;

  AlternativeDrugItem({
    required this.medicine,
    required this.availableStock,
    required this.stockBreakdown,
    required this.latestExpiryStr,
    required this.isAvailable,
  });
}

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
      barrierDismissible: true,
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
  late Future<List<AlternativeDrugItem>> _alternativesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAlternatives();
  }

  void _loadAlternatives() {
    setState(() {
      _alternativesFuture = _fetchAlternativesWithStock();
    });
  }

  Future<List<AlternativeDrugItem>> _fetchAlternativesWithStock() async {
    final rawAlts = await ClinicalAiService.findSmartAlternatives(widget.targetMedicine);
    final invRepo = sl<InventoryRepository>();
    final List<AlternativeDrugItem> items = [];

    for (final alt in rawAlts) {
      final stock = await invRepo.getAvailableQuantity(alt.id);
      final batches = await invRepo.getBatchesForMedicine(alt.id);

      String expiryStr = '—';
      if (batches.isNotEmpty) {
        final firstExp = batches.first.expiryDate;
        if (firstExp != null) {
          expiryStr = '${firstExp.year}-${firstExp.month.toString().padLeft(2, '0')}';
        }
      }

      String breakdown = '';
      final qtyPerPack = (alt.qtyPerPack != null && alt.qtyPerPack! > 0) ? alt.qtyPerPack! : 1;
      final qtyPerStrip = (alt.qtyPerStrip != null && alt.qtyPerStrip! > 0) ? alt.qtyPerStrip! : 1;

      if (stock <= 0) {
        breakdown = 'غير متوفر (0 بالمخزن)';
      } else if (alt.medicineType == 3) {
        breakdown = '$stock علبة';
      } else if (alt.medicineType == 2) {
        final packs = stock ~/ qtyPerPack;
        final pills = stock % qtyPerPack;
        if (packs > 0 && pills > 0) {
          breakdown = '$packs باكت و $pills إبرة';
        } else if (packs > 0) {
          breakdown = '$packs باكت';
        } else {
          breakdown = '$pills إبرة';
        }
      } else {
        final pillsPerPack = qtyPerPack * qtyPerStrip;
        final packs = stock ~/ (pillsPerPack > 0 ? pillsPerPack : 1);
        final rem = stock % (pillsPerPack > 0 ? pillsPerPack : 1);
        final strips = rem ~/ (qtyPerStrip > 0 ? qtyPerStrip : 1);
        final pills = rem % (qtyPerStrip > 0 ? qtyPerStrip : 1);

        final parts = <String>[];
        if (packs > 0) parts.add('$packs باكت');
        if (strips > 0) parts.add('$strips شريط');
        if (pills > 0 || parts.isEmpty) parts.add('$pills حبة');
        breakdown = parts.join(' و ');
      }

      items.add(AlternativeDrugItem(
        medicine: alt,
        availableStock: stock,
        stockBreakdown: breakdown,
        latestExpiryStr: expiryStr,
        isAvailable: stock > 0,
      ));
    }

    // فرز البدائل: المتوفرة في المخزن أولاً
    items.sort((a, b) {
      if (a.isAvailable && !b.isAvailable) return -1;
      if (!a.isAvailable && b.isAvailable) return 1;
      return b.availableStock.compareTo(a.availableStock);
    });

    return items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final targetPrice = widget.targetMedicine.sellingPrice;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          width: 1100,
          constraints: const BoxConstraints(maxHeight: 700, minHeight: 450),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. رأس النافذة الرئيسي
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFECFDF5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFA7F3D0),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horizontal_circle_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 16,
                                fontFamily: 'Segoe UI',
                              ),
                              children: [
                                const TextSpan(
                                  text: 'بدائل الدواء المطلوب في السلة: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: widget.targetMedicine.nameAr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'المادة الفعالة: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    widget.targetMedicine.nameScientific?.isNotEmpty == true
                                        ? widget.targetMedicine.nameScientific!
                                        : 'غير محدد علمياً',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'سعر الوحدة الحالي: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '${targetPrice.toStringAsFixed(0)} ر.ي',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.amber[300] : Colors.amber[800],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF059669)),
                      tooltip: 'إعادة فحص المخزون والبدائل',
                      onPressed: _loadAlternatives,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'إغلاق النافذة',
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),

              // 2. شريط البحث والتصفية
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'تصفية وبحث في قائمة البدائل بالاسم، المادة الفعالة، أو الشركة المصنعة...',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _filterQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _filterQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) => setState(() => _filterQuery = val.trim().toLowerCase()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. رأس جدول البدائل
              Container(
                color: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: const Row(
                  children: [
                    SizedBox(width: 35, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
                    SizedBox(width: 230, child: Text('اسم الدواء البديل', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
                    SizedBox(width: 180, child: Text('المادة الفعالة / التركيب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
                    SizedBox(width: 140, child: Text('الشركة المصنعة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
                    SizedBox(width: 170, child: Text('المخزون المتوفر والتاريخ 📦', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
                    SizedBox(width: 90, child: Text('سعر الوحدة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
                    SizedBox(width: 110, child: Text('فرق السعر', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
                    Expanded(child: Text('إجراء الاستبدال الفوري', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
                  ],
                ),
              ),

              // 4. جسم جدول البدائل
              Expanded(
                child: FutureBuilder<List<AlternativeDrugItem>>(
                  future: _alternativesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF10B981)),
                            SizedBox(height: 12),
                            Text('جاري فحص كميات المخزون وتجهيز البدائل المتوفرة...', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'تعذر جلب البدائل: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final allList = snapshot.data ?? [];
                    final filteredList = _filterQuery.isEmpty
                        ? allList
                        : allList.where((item) {
                            final m = item.medicine;
                            final nameAr = m.nameAr.toLowerCase();
                            final nameEn = (m.nameEn ?? '').toLowerCase();
                            final company = (m.companyName ?? '').toLowerCase();
                            final sci = (m.nameScientific ?? '').toLowerCase();
                            return nameAr.contains(_filterQuery) ||
                                nameEn.contains(_filterQuery) ||
                                company.contains(_filterQuery) ||
                                sci.contains(_filterQuery);
                          }).toList();

                    if (filteredList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              allList.isEmpty
                                  ? 'لا توجد بدائل مسجلة بنفس المادة الفعالة للدواء (${widget.targetMedicine.nameAr})'
                                  : 'لا توجد نتائج مطابقة لبحثك في البدائل',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }

                    return Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (context, altIndex) {
                          final altItem = filteredList[altIndex];
                          final alt = altItem.medicine;
                          final isEven = altIndex % 2 == 0;
                          final altPrice = alt.sellingPrice;
                          final priceDiff = altPrice - targetPrice;
                          final isAvailable = altItem.isAvailable;

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (isEven ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
                                  : (isEven ? Colors.white : const Color(0xFFF8FAFC)),
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 35,
                                  child: Text(
                                    '${altIndex + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12),
                                  ),
                                ),
                                SizedBox(
                                  width: 230,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        alt.nameAr,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (alt.nameEn != null && alt.nameEn!.isNotEmpty)
                                        Text(
                                          alt.nameEn!,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    alt.nameScientific ?? 'غير محدد',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: Text(
                                    alt.companyName ?? alt.categoryName ?? '—',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF475569)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // عمود المخزون الحقيقي المتاح
                                SizedBox(
                                  width: 170,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isAvailable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isAvailable ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isAvailable ? Icons.check_circle : Icons.cancel_outlined,
                                              size: 13,
                                              color: isAvailable ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                altItem.stockBreakdown,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isAvailable ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isAvailable && altItem.latestExpiryStr != '—')
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2, right: 2),
                                          child: Text(
                                            'أقرب انتهاء: ${altItem.latestExpiryStr}',
                                            style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    '${altPrice.toStringAsFixed(0)} ر.ي',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    priceDiff == 0
                                        ? 'مطابق بالسعر'
                                        : (priceDiff > 0
                                            ? '+${priceDiff.toStringAsFixed(0)} ر.ي (أغلى)'
                                            : '${priceDiff.toStringAsFixed(0)} ر.ي (أرخص)'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: priceDiff == 0
                                          ? Colors.blueGrey
                                          : (priceDiff > 0 ? Colors.orange.shade800 : Colors.green.shade800),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: isAvailable
                                        ? FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                            label: const Text(
                                              'استبدال فوري 🔄',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () {
                                              widget.onAlternativeSelected?.call(alt);
                                              Navigator.of(context).pop(alt);
                                            },
                                          )
                                        : OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red.shade400,
                                              side: BorderSide(color: Colors.red.shade200),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.block, size: 14),
                                            label: const Text(
                                              'غير متوفر ❌',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('⚠️ دواء "${alt.nameAr}" غير متوفر في المخزون (الرصيد: 0) ولا يمكن صرفه!'),
                                                  backgroundColor: Colors.red.shade800,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // 5. شريط الإغلاق السفلي
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '💡 يتم عرض البدائل المتوفرة في المخزون أولاً لمنع صرف أصناف بدون رصيد.',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.grey[300] : const Color(0xFF475569),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('إغلاق'),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
