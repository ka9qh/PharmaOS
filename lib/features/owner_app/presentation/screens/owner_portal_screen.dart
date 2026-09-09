import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/services/tele_pharmacy_service.dart';
import '../../../../core/services/license_service.dart';
import '../../../prescriptions/presentation/screens/tele_consultation_dialog.dart';

class OwnerPortalScreen extends StatefulWidget {
  const OwnerPortalScreen({super.key});

  @override
  State<OwnerPortalScreen> createState() => _OwnerPortalScreenState();
}

class _OwnerPortalScreenState extends State<OwnerPortalScreen> {
  bool _isLoading = false;
  String _pharmacyName = 'الصيدلية الرئيسية';
  String _licenseKey = '';
  int _pharmacyId = 1;
  int _branchId = 1;
  List<TeleConsultation> _consultations = [];

  @override
  void initState() {
    super.initState();
    _loadTenantData();
  }

  Future<void> _loadTenantData() async {
    setState(() => _isLoading = true);
    final tenant = await LicenseService.getTenantConfig();
    final pId = int.tryParse(tenant.pharmacyId) ?? 1;
    final bId = int.tryParse(tenant.branchId) ?? 1;
    final consultations = await TelePharmacyService.fetchConsultations(customPharmacyId: pId);

    if (mounted) {
      setState(() {
        _pharmacyName = tenant.pharmacyName;
        _licenseKey = tenant.licenseKey;
        _pharmacyId = pId;
        _branchId = bId;
        _consultations = consultations;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.phone_android_rounded, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text('بوابة تطبيق المدير السحابي (PharmaOS Owner Hub)', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadTenantData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // بطاقة تعريف الصيدلية المعزولة سحابياً
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cloud_sync_rounded, color: Colors.cyanAccent, size: 36),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_pharmacyName (معرف الصيدلية: #$_pharmacyId)',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'الفرع الحالي: #$_branchId • كود الترخيص: $_licenseKey',
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                                const SizedBox(height: 6),
                                const Row(
                                  children: [
                                    Icon(Icons.security_rounded, color: Colors.greenAccent, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'حماية وعزل أمني تام (Supabase RLS) - لا تداخل بين الصيدليات',
                                      style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            ),
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('إرسال روشتة جديدة للمدير 🚀'),
                            onPressed: () => TeleConsultationDialog.show(context),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // إرشادات تطبيق المدير للجوال
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.cyanAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'كيفية تشغيل تطبيق الجوال لمدير الصيدلية (Android / iOS):',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildInstructionStep('1', 'افتح تطبيق PharmaOS Owner على هاتف المدير (أندرويد أو آيفون).'),
                          _buildInstructionStep('2', 'أدخل كود الصيدلية (#$_pharmacyId) واسم الصيدلية للدخول الفوري.'),
                          _buildInstructionStep('3', 'يصل إشعار فوري لمدير الصيدلية عند إرفاق أي روشتة أو استشارة مع صورة عالية الدقة.'),
                          _buildInstructionStep('4', 'يرد المدير بالاسم الدقيق للعلاج والجرعة ويصل الرد للصيدلي ويضاف لسلة البيع بنقرة واحدة!'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // سجل الاستشارات المباشرة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'غرفة الاستشارات والروشتات المتزامنة',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${_consultations.length} استشارة',
                          style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_consultations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text('لا توجد استشارات مسجلة حالياً', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _consultations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final item = _consultations[index];
                          final isAnswered = item.status == 'answered';
                          final isResolved = item.status == 'resolved';

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isAnswered ? Colors.greenAccent.withOpacity(0.5) : (isResolved ? Colors.white10 : Colors.amber.withOpacity(0.5)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isAnswered ? Colors.green.withOpacity(0.15) : (isResolved ? Colors.white10 : Colors.amber.withOpacity(0.15)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isAnswered ? Icons.check_circle_outline : (isResolved ? Icons.done_all : Icons.pending_outlined),
                                    color: isAnswered ? Colors.greenAccent : (isResolved ? Colors.grey : Colors.amberAccent),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'المرسل: ${item.pharmacistName} • ${intl.DateFormat("hh:mm a - yyyy/MM/dd").format(item.createdAt)}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                      if (item.managerReply != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'رد المدير: ${item.managerReply} (الدواء: ${item.suggestedMedicines ?? "-"})',
                                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (item.imageBase64 != null)
                                  const Text('📷 روشتة مرفقة', style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInstructionStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), shape: BoxShape.circle),
            child: Text(num, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }
}
