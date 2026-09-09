// نافذة الربط السريع والتصحيح لباركودات علب/باكت الأدوية مباشرة عبر قارئ الباركود
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/medicines_entity.dart';
import '../../domain/repositories/medicines_repository.dart';
import '../../../../core/di/service_locator.dart';

class AssignBoxBarcodeDialog extends StatefulWidget {
  final MedicineEntity medicine;
  final Function(String newBarcode)? onBarcodeAssigned;

  const AssignBoxBarcodeDialog({
    super.key,
    required this.medicine,
    this.onBarcodeAssigned,
  });

  static Future<bool?> show(
    BuildContext context, {
    required MedicineEntity medicine,
    Function(String newBarcode)? onBarcodeAssigned,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AssignBoxBarcodeDialog(
        medicine: medicine,
        onBarcodeAssigned: onBarcodeAssigned,
      ),
    );
  }

  @override
  State<AssignBoxBarcodeDialog> createState() => _AssignBoxBarcodeDialogState();
}

class _AssignBoxBarcodeDialogState extends State<AssignBoxBarcodeDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isLoading = false;
  MedicineEntity? _conflictingMedicine;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _barcodeController.text = widget.medicine.barcode;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // التركيز الفوري على حقل القارئ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkBarcodeConflict(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty || trimmed == widget.medicine.barcode) {
      setState(() {
        _conflictingMedicine = null;
        _errorMessage = null;
      });
      return;
    }

    final existing = await sl<MedicinesRepository>().getByBarcode(trimmed);
    if (mounted) {
      setState(() {
        if (existing != null && existing.id != widget.medicine.id) {
          _conflictingMedicine = existing;
          _errorMessage = 'الباركود مسجل مسبقاً للدواء: ${existing.nameAr}';
        } else {
          _conflictingMedicine = null;
          _errorMessage = null;
        }
      });
    }
  }

  Future<void> _saveBarcode({bool forceOverride = false}) async {
    final newBarcode = _barcodeController.text.trim();

    setState(() => _isLoading = true);

    try {
      final success = await sl<MedicinesRepository>().updateBarcode(
        widget.medicine.id,
        newBarcode,
        forceOverride: forceOverride,
      );

      if (success) {
        // نغمة نجاح خفيفة
        SystemSound.play(SystemSoundType.click);

        widget.onBarcodeAssigned?.call(newBarcode);

        if (mounted) {
          Navigator.of(context).pop(true);
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
                      newBarcode.isEmpty
                          ? 'تم إلغاء وحذف الباركود بنجاح'
                          : 'تم اعتماد وتثبيت باركود العلبة [$newBarcode] بنجاح',
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
            _errorMessage = 'حدث خطأ أثناء حفظ الباركود. يرجى المحاولة ثانية.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ: $e';
          _isLoading = false;
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
          width: 520,
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
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF3B82F6), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ربط وتعديل باركود العلبة / الباكت',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'مسح باركود الشركة المصنعة مباشرة بدون الحاجة للطباعة',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // بطاقة معلومات الدواء الحالي
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.medication_rounded, color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.medicine.nameAr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.medicine.nameScientific != null && widget.medicine.nameScientific!.isNotEmpty)
                            Text(
                              widget.medicine.nameScientific!,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'السعر: ${widget.medicine.sellingPrice} ر.ي  |  الوحدة: ${widget.medicine.unit}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // منطقة المسح الضوئي التفاعلية
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.barcode_reader, color: Color(0xFF3B82F6), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'مرر قارئ الباركود على علبة الدواء الآن',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6), fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _barcodeController,
                        focusNode: _barcodeFocusNode,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'أو اكتب رقم الباركود هنا...',
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400], letterSpacing: 0),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                          ),
                          suffixIcon: _barcodeController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Colors.red),
                                  tooltip: 'مسح الحقل',
                                  onPressed: () {
                                    _barcodeController.clear();
                                    _checkBarcodeConflict('');
                                    _barcodeFocusNode.requestFocus();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) => _checkBarcodeConflict(val),
                        onSubmitted: (val) => _saveBarcode(),
                      ),
                    ],
                  ),
                ),
              ),

              // رسائل التحذير من تكرار الباركود
              if (_conflictingMedicine != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تنبيه تعارض: الباركود مربوط مسبقاً بدواء آخر!',
                              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اسم الدواء الحالي: ${_conflictingMedicine!.nameAr}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('نقل الباركود واعتماده لهذا الدواء (تصحيح)'),
                          onPressed: _isLoading ? null : () => _saveBarcode(forceOverride: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // أزرار التحكم والإجراءات
              Row(
                children: [
                  // زر حذف الباركود
                  if (widget.medicine.barcode.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('إلغاء الباركود'),
                      onPressed: _isLoading
                          ? null
                          : () {
                              _barcodeController.clear();
                              _saveBarcode();
                            },
                    ),

                  const Spacer(),

                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('حفظ واعتماد الباركود', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isLoading || _conflictingMedicine != null ? null : () => _saveBarcode(),
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
