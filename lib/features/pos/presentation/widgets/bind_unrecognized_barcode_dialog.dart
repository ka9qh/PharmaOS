// نافذة ربط الباركود الجديد غير المسجل بدواء فوري من نقطة البيع
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../../core/di/service_locator.dart';

class BindUnrecognizedBarcodeDialog extends StatefulWidget {
  final String scannedBarcode;

  const BindUnrecognizedBarcodeDialog({
    super.key,
    required this.scannedBarcode,
  });

  static Future<MedicineEntity?> show(
    BuildContext context, {
    required String scannedBarcode,
  }) {
    return showDialog<MedicineEntity>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BindUnrecognizedBarcodeDialog(scannedBarcode: scannedBarcode),
    );
  }

  @override
  State<BindUnrecognizedBarcodeDialog> createState() => _BindUnrecognizedBarcodeDialogState();
}

class _BindUnrecognizedBarcodeDialogState extends State<BindUnrecognizedBarcodeDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<MedicineEntity> _searchResults = [];
  MedicineEntity? _selectedMedicine;
  bool _isSearching = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await sl<MedicinesRepository>().getAll(searchQuery: q);
      if (mounted) {
        setState(() {
          _searchResults = results.take(20).toList();
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveAndBind() async {
    if (_selectedMedicine == null) return;

    setState(() => _isSaving = true);

    try {
      final success = await sl<MedicinesRepository>().updateBarcode(
        _selectedMedicine!.id,
        widget.scannedBarcode.trim(),
        forceOverride: true,
      );

      if (success) {
        SystemSound.play(SystemSoundType.click);

        final updatedMedicine = _selectedMedicine!.copyWith(
          barcode: widget.scannedBarcode.trim(),
        );

        if (mounted) {
          Navigator.of(context).pop(updatedMedicine);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم ربط الباركود [${widget.scannedBarcode}] بالدواء [${_selectedMedicine!.nameAr}] بنجاح!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'تعذر ربط الباركود. يرجى المحاولة ثانية.';
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ: $e';
          _isSaving = false;
        });
      }
    }
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
          width: 580,
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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFF59E0B), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'باركود علبة جديد غير مسجل',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'حدد الصنف من دليل الأدوية لربط باركود العلبة به فوراً',
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

              // بطاقة الباركود الممسوح
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.barcode_reader, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 10),
                    const Text('الباركود المقروء:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Text(
                        widget.scannedBarcode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // حقل البحث السريع في الأدوية
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  labelText: 'ابحث عن اسم الدواء لربطه (عربي / إنجليزي / علمي)',
                  hintText: 'مثال: بارامول، بنادول، أوجمنتين...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3B82F6)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                ),
                onChanged: _performSearch,
              ),

              const SizedBox(height: 12),

              // قائمة نتائج البحث
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'اكتب اسم الدواء أعلاه للبحث والربط'
                                  : 'لا توجد نتائج مطابقة لبحثك',
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final med = _searchResults[index];
                              final isSelected = _selectedMedicine?.id == med.id;

                              return InkWell(
                                onTap: () => setState(() => _selectedMedicine = med),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(color: const Color(0xFF10B981))
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: isSelected ? const Color(0xFF10B981) : Colors.grey[400],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              med.nameAr,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isSelected ? const Color(0xFF10B981) : null,
                                              ),
                                            ),
                                            if (med.nameScientific != null && med.nameScientific!.isNotEmpty)
                                              Text(
                                                med.nameScientific!,
                                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${med.sellingPrice} ر.ي',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                                          ),
                                          Text(
                                            med.unit,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 16),

              // أزرار الحفظ والإلغاء
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
                    child: const Text('تخطي / إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.link_rounded),
                    label: const Text('ربط الباركود وإضافة للفاتورة', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _selectedMedicine == null || _isSaving ? null : _saveAndBind,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
