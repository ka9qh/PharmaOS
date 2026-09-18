// تبويب غرفة الروشتات والاستشارات الطبية الفورية - PharmaOS Owner App
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../models/models.dart';
import '../services/owner_api_service.dart';
import 'prescription_viewer_screen.dart';

class TelePharmacyTab extends StatefulWidget {
  const TelePharmacyTab({super.key});

  @override
  State<TelePharmacyTab> createState() => _TelePharmacyTabState();
}

class _TelePharmacyTabState extends State<TelePharmacyTab> {
  bool _isLoading = false;
  List<OwnerTeleConsultation> _consultations = [];
  String _selectedFilter = 'all'; // all, pending, answered, resolved

  @override
  void initState() {
    super.initState();
    _loadConsultations();
  }

  Future<void> _loadConsultations() async {
    setState(() => _isLoading = true);
    final status = _selectedFilter == 'all' ? null : _selectedFilter;
    final list = await OwnerApiService.fetchTeleConsultations(status: status);
    if (mounted) {
      setState(() {
        _consultations = list;
        _isLoading = false;
      });
    }
  }

  void _showReplyDialog(OwnerTeleConsultation item) {
    final replyCtrl = TextEditingController(text: item.managerReply ?? '');
    final medCtrl = TextEditingController(text: item.suggestedMedicines ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.quickreply_rounded, color: Colors.cyanAccent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'الرد على: ${item.title}',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.notes != null) ...[
                  Text('ملاحظة الصيدلي: ${item.notes}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: replyCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'نص التوجيه / الرد للصيدلي',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'مثال: العلاج بالسطر الثاني هو Augmentin 1g مرتين يومياً',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: medCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'اسم الدواء الدقيق (لإضافته لسلة الصيدلي فوراً)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'مثال: Augmentin 1g Tab',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.medication_rounded, color: Colors.cyanAccent),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: () async {
                if (replyCtrl.text.trim().isEmpty && medCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final ok = await OwnerApiService.replyConsultation(
                  consultationId: item.id,
                  reply: replyCtrl.text.trim().isEmpty ? 'تمت مراجعة الروشتة وتأكيد الصرف' : replyCtrl.text.trim(),
                  suggestedMedicines: medCtrl.text.trim().isEmpty ? null : medCtrl.text.trim(),
                );
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم إرسال الرد للصيدلي في النظام المكتبي فوراً!'), backgroundColor: Colors.green),
                  );
                  _loadConsultations();
                }
              },
              child: const Text('إرسال التوجيه 🚀'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1322).withValues(alpha: 0.85),
        elevation: 0,
        title: const Text('غرفة الروشتات والاستشارات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadConsultations,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الفلاتر السريع
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                _buildFilterChip('all', 'الكل'),
                const SizedBox(width: 8),
                _buildFilterChip('pending', '⏳ بانتظار الرد'),
                const SizedBox(width: 8),
                _buildFilterChip('answered', '💬 تم الرد'),
                const SizedBox(width: 8),
                _buildFilterChip('resolved', '✅ مكتملة'),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _consultations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mark_chat_read_outlined, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 12),
                            const Text('لا توجد استشارات أو روشتات قيد الانتظار', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadConsultations,
                        color: Colors.cyanAccent,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _consultations.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final item = _consultations[index];
                            final timeStr = intl.DateFormat('hh:mm a - yyyy/MM/dd').format(item.createdAt);
                            final isPending = item.status == 'pending';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPending
                                      ? Colors.amber.shade400
                                      : (item.status == 'answered' ? Colors.cyanAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                                  width: isPending ? 1.5 : 1,
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
                                          color: isPending
                                              ? Colors.amber.withOpacity(0.15)
                                              : (item.status == 'answered' ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isPending ? '⏳ قيد الانتظار' : (item.status == 'answered' ? '💬 تم الرد' : '✅ تم الصرف'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isPending ? Colors.amberAccent : (item.status == 'answered' ? Colors.greenAccent : Colors.grey),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item.urgency == 'critical')
                                        const Text('🔴 طارئ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent))
                                      else if (item.urgency == 'urgent')
                                        const Text('🟠 عاجل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                    ],
                                  ),

                                  const SizedBox(height: 8),
                                  Text(
                                    'المرسل: ${item.pharmacistName} • $timeStr',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),

                                  if (item.notes != null) ...[
                                    const SizedBox(height: 6),
                                    Text('الملاحظات: ${item.notes}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],

                                  // صورة الروشتة المرفقة
                                  if (item.imageBase64 != null) ...[
                                    const SizedBox(height: 12),
                                    InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PrescriptionViewerScreen(
                                            consultation: item,
                                            onReplyRequested: () => _showReplyDialog(item),
                                          ),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 140,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.memory(
                                                base64Decode(item.imageBase64!),
                                                fit: BoxFit.cover,
                                              ),
                                              Container(
                                                color: Colors.black38,
                                                child: const Center(
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.zoom_in_rounded, color: Colors.white, size: 24),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'انقر لتكبير وقراءة الروشتة 🔍',
                                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  // رد المدير المسجل
                                  if (item.managerReply != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ردك للصيدلي: ${item.managerReply}',
                                            style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          if (item.suggestedMedicines != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'الدواء المقترح: ${item.suggestedMedicines}',
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                                        foregroundColor: Colors.cyanAccent,
                                      ),
                                      icon: const Icon(Icons.reply_rounded, size: 18),
                                      label: Text(item.managerReply != null ? 'تعديل الرد' : 'الرد على الصيدلي ✍️'),
                                      onPressed: () => _showReplyDialog(item),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = key);
        _loadConsultations();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
