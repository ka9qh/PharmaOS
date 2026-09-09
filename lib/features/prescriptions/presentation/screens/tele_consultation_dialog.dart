// نافذة الاستشارة الطبية المباشرة وقراءة الروشتات مع المدير - PharmaOS
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/tele_pharmacy_service.dart';
import '../../../../core/services/license_service.dart';

class TeleConsultationDialog extends StatefulWidget {
  final Function(String medicineName)? onAddSuggestedMedicineToCart;

  const TeleConsultationDialog({
    super.key,
    this.onAddSuggestedMedicineToCart,
  });

  static Future<void> show(BuildContext context, {Function(String medicineName)? onAddSuggestedMedicineToCart}) {
    return showDialog(
      context: context,
      builder: (ctx) => TeleConsultationDialog(onAddSuggestedMedicineToCart: onAddSuggestedMedicineToCart),
    );
  }

  @override
  State<TeleConsultationDialog> createState() => _TeleConsultationDialogState();
}

class _TeleConsultationDialogState extends State<TeleConsultationDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _patientController = TextEditingController();
  String _urgency = 'normal';
  String? _selectedImageBase64;
  String? _selectedImageName;
  bool _isSending = false;
  bool _isLoadingList = false;
  List<TeleConsultation> _consultations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConsultations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _patientController.dispose();
    super.dispose();
  }

  Future<void> _loadConsultations() async {
    setState(() => _isLoadingList = true);
    final list = await TelePharmacyService.fetchConsultations();
    if (mounted) {
      setState(() {
        _consultations = list;
        _isLoadingList = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedImageBase64 = base64Encode(bytes);
        _selectedImageName = result.files.single.name;
      });
    }
  }

  Future<void> _submitConsultation() async {
    if (_titleController.text.trim().isEmpty && _selectedImageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة عنوان أو إرفاق صورة الروشتة أولاً')),
      );
      return;
    }

    setState(() => _isSending = true);
    final tenant = await LicenseService.getTenantConfig();

    final result = await TelePharmacyService.sendConsultation(
      title: _titleController.text.trim().isEmpty ? 'قراءة روشتة طبية' : _titleController.text.trim(),
      patientName: _patientController.text.trim().isEmpty ? null : _patientController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      imageBase64: _selectedImageBase64,
      urgency: _urgency,
      pharmacistName: 'الصيدلي (${tenant.pharmacyName})',
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إرسال الروشتة للمدير بنجاح! سيصلك الرد فوراً'),
            backgroundColor: Colors.green,
          ),
        );
        _titleController.clear();
        _notesController.clear();
        _patientController.clear();
        _selectedImageBase64 = null;
        _selectedImageName = null;
        _loadConsultations();
        _tabController.animateTo(1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ تعذر الإرسال، تحقق من اتصال الإنترنت'),
            backgroundColor: Colors.red,
          ),
        );
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
          width: 820,
          height: 680,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس النافذة
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.wifi_channel_rounded, color: Color(0xFF6366F1), size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'غرفة الاستشارة والروشتات الفورية (Tele-Pharmacy)',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'إرسال الروشتات غير الواضحة والاستشارات للمدير لتأكيد الصرف لحظياً',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث المحادثات',
                    onPressed: _loadConsultations,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // التبويبات
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF6366F1),
                labelColor: const Color(0xFF6366F1),
                unselectedLabelColor: Colors.grey,
                tabs: [
                  const Tab(icon: Icon(Icons.send_rounded), text: 'إرسال استشارة / روشتة جديدة'),
                  Tab(
                    icon: Badge(
                      isLabelVisible: _consultations.where((c) => c.status == 'answered').isNotEmpty,
                      label: Text('${_consultations.where((c) => c.status == 'answered').length}'),
                      child: const Icon(Icons.forum_rounded),
                    ),
                    text: 'سجل الاستشارات وردود المدير (${_consultations.length})',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNewConsultationForm(isDark),
                    _buildConsultationsList(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewConsultationForm(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'عنوان الاستشارة / اسم الطبيب أو العيادة',
                    hintText: 'مثال: روشتة د. علي - خط غير واضح للصنف 2',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _patientController,
                  decoration: InputDecoration(
                    labelText: 'اسم المريض أو العمر (اختياري)',
                    hintText: 'مثال: طفل 4 سنوات',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Text('درجة الأهمية: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('عادي 🟢'),
                selected: _urgency == 'normal',
                onSelected: (s) => setState(() => _urgency = 'normal'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('عاجل 🟠'),
                selected: _urgency == 'urgent',
                onSelected: (s) => setState(() => _urgency = 'urgent'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('طارئ جداً 🔴'),
                selected: _urgency == 'critical',
                onSelected: (s) => setState(() => _urgency = 'critical'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // اختيار أو إرفاق صورة الروشتة
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedImageBase64 != null ? Colors.green : Colors.grey.shade300,
                  width: _selectedImageBase64 != null ? 2 : 1,
                ),
              ),
              child: _selectedImageBase64 != null
                  ? Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                          child: Image.memory(
                            base64Decode(_selectedImageBase64!),
                            width: 180,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedImageName ?? 'صورة الروشتة مرفقة بنجاح',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text('انقر لتغيير الصورة أو استبدالها', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                                label: const Text('إلغاء الصورة', style: TextStyle(color: Colors.red, fontSize: 12)),
                                onPressed: () => setState(() {
                                  _selectedImageBase64 = null;
                                  _selectedImageName = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 48, color: const Color(0xFF6366F1).withValues(alpha: 0.8)),
                          const SizedBox(height: 8),
                          const Text(
                            'انقر لاختيار صورة الروشتة (JPG / PNG / WebP)',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                          ),
                          const Text('يدعم صور الكاميرا والماسح الضوئي واللقطات', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'ملاحظات إضافية للصيدلي / الأصناف المشكوك فيها',
              hintText: 'مثال: العلاج الثالث في السطر الأخير هل هو Augmentin 1g أو Amoxil 500؟',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isSending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: Text(
              _isSending ? 'جاري الإرسال السحابي للمدير...' : 'إرسال الروشتة فورياً للمدير 🚀',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: _isSending ? null : _submitConsultation,
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationsList(bool isDark) {
    if (_isLoadingList) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_consultations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('لا توجد استشارات سابقة حتى الآن', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _consultations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final item = _consultations[index];
        final isAnswered = item.status == 'answered';
        final isResolved = item.status == 'resolved';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAnswered ? Colors.green.shade400 : (isResolved ? Colors.grey.shade300 : Colors.amber.shade400),
              width: isAnswered ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAnswered
                          ? Colors.green.shade50
                          : (isResolved ? Colors.grey.shade200 : Colors.amber.shade50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAnswered ? '💬 تم رد المدير' : (isResolved ? '✅ تم الصرف' : '⏳ قيد المراجعة'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isAnswered ? Colors.green.shade800 : (isResolved ? Colors.grey.shade800 : Colors.amber.shade900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              if (item.notes != null) ...[
                const SizedBox(height: 6),
                Text('الملاحظات: ${item.notes}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              ],

              // إذا كانت هناك صورة روشتة مرفقة
              if (item.imageBase64 != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showFullImage(item.imageBase64!),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image, size: 16, color: Colors.blue),
                        SizedBox(width: 6),
                        Text('عرض صورة الروشتة المكبرة 🔍', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],

              // رد المدير إذا وجد
              if (item.managerReply != null) ...[
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
                          const Icon(Icons.verified_user, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'رد ${item.managerName ?? "المدير"}:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.managerReply!,
                        style: TextStyle(color: Colors.green.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      if (item.suggestedMedicines != null && item.suggestedMedicines!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'الدواء المحدد: ${item.suggestedMedicines}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ),
                            if (widget.onAddSuggestedMedicineToCart != null)
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.teal.shade100,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  widget.onAddSuggestedMedicineToCart!(item.suggestedMedicines!);
                                  Navigator.of(context).pop();
                                },
                                child: const Text('إضافة للسلة 🛒', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              if (!isResolved) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.done_all, size: 16, color: Colors.green),
                    label: const Text('تأكيد الصرف وإغلاق الروشتة', style: TextStyle(fontSize: 12, color: Colors.green)),
                    onPressed: () async {
                      await TelePharmacyService.markAsResolved(item.id);
                      _loadConsultations();
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showFullImage(String base64String) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 6.0,
                child: Image.memory(
                  base64Decode(base64String),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
