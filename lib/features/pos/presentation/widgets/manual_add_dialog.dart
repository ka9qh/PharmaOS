// إضافة دواء لسلة نقطة البيع بالبحث الذكي + البحث عن البدائل المتوفرة بالمخزون + البحث السحابي بـ Gemini AI
// يدعم: اختيار وحدة البيع (باكت / شريط / حبة / علبة)، استخراج البدائل المتوفرة، والذكاء الاصطناعي عند عدم التوفر.

import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/gemini_online_ai_service.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../inventory/domain/repositories/inventory_repository.dart';
import '../../../../core/services/medicine_clinical_helper.dart';
import '../../../medicines/presentation/widgets/medicine_clinical_details_dialog.dart';

class _UnitOption {
  final String name;
  final String label;
  final IconData icon;
  final double unitPrice;
  final int multiplier;
  int quantity;

  _UnitOption({
    required this.name,
    required this.label,
    required this.icon,
    required this.unitPrice,
    required this.multiplier,
    this.quantity = 0,
  });

  double get subtotal => unitPrice * quantity;
}

Future<void> showManualAddToCartDialog(
  BuildContext context, {
  MedicineEntity? initialMedicine,
  required void Function(MedicineEntity medicine, int selectedQuantity, String unitName, int unitMultiplier, double unitPrice) onAdd,
}) async {
  final searchController = TextEditingController(text: initialMedicine?.nameAr ?? '');
  List<MedicineEntity> results = [];
  List<MedicineEntity> inStockAlternatives = [];
  MedicineEntity? selected = initialMedicine;
  
  final List<_UnitOption> unitOptions = [];
  bool isSearching = false;
  bool isAiSearching = false;
  String? aiResponseText;
  Timer? _debounceTimer;

  void buildUnitOptions(MedicineEntity med) {
    unitOptions.clear();
    final qtyPerCarton = (med.qtyPerCarton != null && med.qtyPerCarton! > 0) ? med.qtyPerCarton! : 1;
    final qtyPerPack = (med.qtyPerPack != null && med.qtyPerPack! > 0) ? med.qtyPerPack! : 1;
    final qtyPerStrip = (med.qtyPerStrip != null && med.qtyPerStrip! > 0) ? med.qtyPerStrip! : 1;

    final pillPrice = med.sellingPrice > 0 ? med.sellingPrice : 10.0;

    final packPrice = (med.packSellingPrice != null && med.packSellingPrice! > 0) 
        ? med.packSellingPrice! 
        : (med.medicineType == 2 
            ? pillPrice * qtyPerPack 
            : pillPrice * qtyPerPack * qtyPerStrip);
        
    final stripPrice = (med.stripSellingPrice != null && med.stripSellingPrice! > 0)
        ? med.stripSellingPrice!
        : (pillPrice * qtyPerStrip);

    final cartonPrice = (med.cartonSellingPrice != null && med.cartonSellingPrice! > 0)
        ? med.cartonSellingPrice!
        : (med.medicineType == 3 || med.medicineType == 4 
            ? pillPrice * qtyPerCarton 
            : (med.medicineType == 2 ? packPrice * qtyPerCarton : packPrice * qtyPerCarton));

    if (med.medicineType == 3) {
      // شراب وعصير وقطرات
      unitOptions.add(_UnitOption(
        name: 'علبة',
        label: 'علبة كاملة',
        icon: Icons.water_drop_outlined,
        unitPrice: pillPrice,
        multiplier: 1,
        quantity: 1,
      ));
      if (med.qtyPerCarton != null && med.qtyPerCarton! > 1) {
        unitOptions.add(_UnitOption(
          name: 'كرتون',
          label: 'كرتون (${med.qtyPerCarton} علبة)',
          icon: Icons.archive_outlined,
          unitPrice: cartonPrice,
          multiplier: qtyPerCarton,
          quantity: 0,
        ));
      }
    } else if (med.medicineType == 2) {
      // حقن وإبر
      unitOptions.add(_UnitOption(
        name: 'باكت',
        label: 'باكت كامل (${qtyPerPack} إبرة)',
        icon: Icons.inventory_2_outlined,
        unitPrice: packPrice,
        multiplier: qtyPerPack,
        quantity: 1,
      ));
      unitOptions.add(_UnitOption(
        name: 'حبة',
        label: 'حبة (إبرة مفردة)',
        icon: Icons.colorize_outlined,
        unitPrice: pillPrice,
        multiplier: 1,
        quantity: 0,
      ));
      if (med.qtyPerCarton != null && med.qtyPerCarton! > 1) {
        unitOptions.add(_UnitOption(
          name: 'كرتون',
          label: 'كرتون (${qtyPerCarton} باكت)',
          icon: Icons.archive_outlined,
          unitPrice: cartonPrice,
          multiplier: qtyPerCarton * qtyPerPack,
          quantity: 0,
        ));
      }
    } else {
      // حبوب وأقراص ومستحضرات
      unitOptions.add(_UnitOption(
        name: 'باكت',
        label: 'باكت كامل',
        icon: Icons.inventory_2_outlined,
        unitPrice: packPrice,
        multiplier: qtyPerPack * qtyPerStrip,
        quantity: 1,
      ));
      if (med.medicineType == 1 || qtyPerPack > 1) {
        unitOptions.add(_UnitOption(
          name: 'شريط',
          label: 'شريط مفرد (${qtyPerStrip} حبة)',
          icon: Icons.view_headline,
          unitPrice: stripPrice,
          multiplier: qtyPerStrip,
          quantity: 0,
        ));
      }
      unitOptions.add(_UnitOption(
        name: 'حبة',
        label: 'حبة مفردة',
        icon: Icons.circle_outlined,
        unitPrice: pillPrice,
        multiplier: 1,
        quantity: 0,
      ));
      if (med.qtyPerCarton != null && med.qtyPerCarton! > 1) {
        unitOptions.add(_UnitOption(
          name: 'كرتون',
          label: 'كرتون (${qtyPerCarton} باكت)',
          icon: Icons.archive_outlined,
          unitPrice: cartonPrice,
          multiplier: qtyPerCarton * qtyPerPack * qtyPerStrip,
          quantity: 0,
        ));
      }
    }
  }

  if (initialMedicine != null) {
    buildUnitOptions(initialMedicine);
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_shopping_cart, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('إضافة دواء لسلة البيع والبحث الذكي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selected == null) ...[
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.blue),
                        hintText: 'ابحث باسم الدواء (عربي/إنجليزي)، المادة الفعالة، أو الباركود...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      onChanged: (query) {
                        final q = query.trim();
                        if (q.length < 2) {
                          setState(() {
                            results = [];
                            inStockAlternatives = [];
                            aiResponseText = null;
                          });
                          return;
                        }
                        setState(() {
                          isSearching = true;
                          aiResponseText = null;
                        });

                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
                          if (!context.mounted) return;
                          
                          final found = await sl<MedicinesRepository>().getAll(searchQuery: q);
                          List<MedicineEntity> alternatives = [];

                          if (found.isNotEmpty) {
                            final targetSci = found.first.nameScientific;
                            if (targetSci != null && targetSci.isNotEmpty) {
                              final allAlts = await sl<MedicinesRepository>().getAlternatives(found.first.id, targetSci);
                              final invRepo = sl<InventoryRepository>();
                              for (var m in allAlts) {
                                final stock = await invRepo.getAvailableQuantity(m.id);
                                if (stock > 0) {
                                  alternatives.add(m);
                                }
                                if (alternatives.length >= 4) break;
                              }
                            }
                          }

                          if (context.mounted) {
                            setState(() {
                              results = found;
                              inStockAlternatives = alternatives;
                              isSearching = false;
                            });
                          }
                        });
                      },
                    ),

                    if (isSearching)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),

                    // تبويب البدائل المتوفرة في المخزون
                    if (inStockAlternatives.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.sync_alt, color: Colors.green, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '💊 بدائل متطابقة متوفرة بالمخزون (${inStockAlternatives.length}):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: inStockAlternatives.map((alt) {
                                return ActionChip(
                                  backgroundColor: Colors.white,
                                  avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  label: Text('${alt.nameAr} (${alt.sellingPrice.toStringAsFixed(0)} ر.ي)'),
                                  onPressed: () {
                                    setState(() {
                                      selected = alt;
                                      buildUnitOptions(alt);
                                      results = [];
                                      inStockAlternatives = [];
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // نتائج البحث في كتالوج الـ 30 ألف دواء
                    if (results.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final med = results[index];
                            return ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFFF1F5F9),
                                child: Icon(Icons.medication, size: 16, color: Colors.blue),
                              ),
                              title: Text(med.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${med.nameEn ?? ""} | ${med.nameScientific ?? med.companyName ?? "دليل الصيدلية"} | ${med.sellingPrice.toStringAsFixed(0)} ر.ي',
                                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () {
                                setState(() {
                                  selected = med;
                                  buildUnitOptions(med);
                                  results = [];
                                  inStockAlternatives = [];
                                });
                              },
                            );
                          },
                        ),
                      ),

                    // في حال لم يتم العثور على أي دواء محلياً -> زر البحث بالذكاء الاصطناعي Gemini
                    if (!isSearching && results.isEmpty && searchController.text.trim().length >= 2) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'الدواء غير مسجل محلياً في الكتالوج',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3730A3)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'اضغط للبحث عبر الذكاء الاصطناعي (Google Gemini 3.6 Flash) لتحديد التركيبة العلمية والبحث عن بدائلها المتوفرة في صيدليتك فوراً.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF4338CA)),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                                icon: isAiSearching
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.travel_explore, size: 18),
                                label: Text(isAiSearching ? 'جاري البحث السريري بالذكاء الاصطناعي...' : 'بحث سريري بالذكاء الاصطناعي وبدائل المخزون'),
                                onPressed: isAiSearching
                                    ? null
                                    : () async {
                                        setState(() => isAiSearching = true);
                                        try {
                                          final q = searchController.text.trim();
                                          final aiText = await GeminiOnlineAiService.askAi(
                                            prompt: 'ما هي المادة الفعالة واستخدامات وبدائل دواء: $q؟ أجب بالعربي باختصار في 3 أسطر.',
                                          );
                                          setState(() {
                                            aiResponseText = aiText;
                                            isAiSearching = false;
                                          });
                                        } catch (e) {
                                          setState(() {
                                            aiResponseText = 'تأكد من الاتصال بالإنترنت للاستعلام من الذكاء الاصطناعي: $e';
                                            isAiSearching = false;
                                          });
                                        }
                                      },
                              ),
                            ),
                            if (aiResponseText != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  aiResponseText!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // بطاقة الدواء المختار وتحديد الكمية والوحدة
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.medication, color: Colors.blue, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(selected!.nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(
                                      '${selected!.nameEn ?? ""} | ${selected!.nameScientific ?? selected!.companyName ?? ""}',
                                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline, color: Colors.teal),
                                tooltip: 'عرض الإرشادات السريرية والجرعات والبدائل الكاملة',
                                onPressed: () => MedicineClinicalDetailsDialog.show(
                                  context,
                                  medicineId: selected!.id,
                                  fallbackName: selected!.nameAr,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.change_circle_outlined, color: Colors.blue),
                                tooltip: 'تغيير الدواء',
                                onPressed: () => setState(() => selected = null),
                              ),
                            ],
                          ),

                          // --- شريط الفحص السريري قبل البيع (الحوامل ومرضى القلب والبدائل) ---
                          Builder(
                            builder: (context) {
                              final profile = MedicineClinicalHelper.getFullClinicalProfile(
                                medicineName: selected!.nameAr,
                                scientificName: selected!.nameScientific,
                                categoryName: selected!.categoryName,
                                rawReserve1: selected!.reserveField1,
                                formOrPack: selected!.reserveField2,
                              );

                              final preg = profile.pregnancy;
                              final cardiac = profile.cardiac;

                              return Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (!preg.isSafe || !cardiac.isSafe) ? Colors.red.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (!preg.isSafe || !cardiac.isSafe) ? Colors.red.shade300 : Colors.green.shade300,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          (!preg.isSafe || !cardiac.isSafe) ? Icons.warning_amber_rounded : Icons.verified,
                                          size: 16,
                                          color: (!preg.isSafe || !cardiac.isSafe) ? Colors.red.shade700 : Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'تنبيهات الأمان السريري قبل الصرف:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: (!preg.isSafe || !cardiac.isSafe) ? Colors.red.shade900 : Colors.green.shade900,
                                          ),
                                        ),
                                        const Spacer(),
                                        InkWell(
                                          onTap: () => MedicineClinicalDetailsDialog.show(
                                            context,
                                            medicineId: selected!.id,
                                            fallbackName: selected!.nameAr,
                                          ),
                                          child: const Text(
                                            'عرض كامل البدائل والوصفة ❯',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // مأمونية الحوامل
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          preg.isSafe ? '🤰 مسموح للحوامل' : '🤰 تحذير الحوامل: ${preg.statusLabel}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: preg.isSafe ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (!preg.isSafe)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                                        child: Text(
                                          '💡 البديل للحوامل: ${preg.safeAlternative}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    // مأمونية القلب
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cardiac.isSafe ? '❤️ آمن لمرضى القلب والضغط' : '❤️ تحذير القلب والضغط: ${cardiac.statusLabel}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: cardiac.isSafe ? Colors.teal.shade800 : Colors.deepOrange.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (!cardiac.isSafe)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '💡 البديل لمرضى القلب: ${cardiac.safeAlternative}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF115E59), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const SizedBox(height: 16),

                    // اختيار وحدات البيع والكميات المتزامنة
                    const Row(
                      children: [
                        Icon(Icons.layers_rounded, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('تحديد الكمية المطلوبة لكل وحدة بيع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // قائمة بطاقات الوحدات (باكت، شريط، حبة، كرتون)
                    ...unitOptions.map((unitOpt) {
                      final hasQty = unitOpt.quantity > 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: hasQty ? Colors.blue.shade50.withOpacity(0.6) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasQty ? Colors.blue.shade400 : Colors.grey.shade300,
                            width: hasQty ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasQty ? Colors.blue.shade100 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(unitOpt.icon, color: hasQty ? Colors.blue.shade800 : Colors.grey.shade700, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    unitOpt.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: hasQty ? Colors.blue.shade900 : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'سعر المفرد: ${unitOpt.unitPrice.toStringAsFixed(0)} ر.ي',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            // أزرار زيادة ونقصان الكمية
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                                  onPressed: unitOpt.quantity > 0
                                      ? () {
                                          setState(() {
                                            unitOpt.quantity--;
                                          });
                                        }
                                      : null,
                                ),
                                Container(
                                  width: 45,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    '${unitOpt.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 22),
                                  onPressed: () {
                                    setState(() {
                                      unitOpt.quantity++;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // مبلغ الوحدة
                            SizedBox(
                              width: 85,
                              child: Text(
                                '${unitOpt.subtotal.toStringAsFixed(0)} ر.ي',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: hasQty ? Colors.green.shade800 : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // ملخص المبالغ والإجمالي الكلي
                    Builder(
                      builder: (context) {
                        final selectedUnits = unitOptions.where((u) => u.quantity > 0).toList();
                        final totalAmount = selectedUnits.fold<double>(0.0, (sum, u) => sum + u.subtotal);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تفاصيل وإجمالي الوحدات المحددة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              if (selectedUnits.isEmpty)
                                const Text('يرجى تحديد كمية 1 على الأقل لأي وحدة أعلاه', style: TextStyle(color: Colors.orange, fontSize: 12))
                              else
                                ...selectedUnits.map((u) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('• مبلغ ${u.label} (${u.quantity} × ${u.unitPrice.toStringAsFixed(0)} ر.ي):', style: const TextStyle(fontSize: 13)),
                                          Text('${u.subtotal.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        ],
                                      ),
                                    )),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('الإجمالي الكلي المطلوب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(
                                    '${totalAmount.toStringAsFixed(0)} ر.ي',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('إضافة للسلة'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: selected == null || unitOptions.where((u) => u.quantity > 0).isEmpty
                  ? null
                  : () {
                      final selectedUnits = unitOptions.where((u) => u.quantity > 0).toList();
                      for (final u in selectedUnits) {
                        onAdd(selected!, u.quantity, u.name, u.multiplier, u.unitPrice);
                      }
                      Navigator.pop(context);
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
