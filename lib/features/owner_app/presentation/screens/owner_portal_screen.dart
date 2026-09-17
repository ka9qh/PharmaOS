import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/services/tele_pharmacy_service.dart';
import '../../../../core/services/license_service.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/owner_live_sync_service.dart';
import '../../../prescriptions/presentation/screens/tele_consultation_dialog.dart';
import '../../../chat/presentation/screens/desktop_live_chat_screen.dart';

class OwnerPortalScreen extends StatefulWidget {
  const OwnerPortalScreen({super.key});

  @override
  State<OwnerPortalScreen> createState() => _OwnerPortalScreenState();
}

class _OwnerPortalScreenState extends State<OwnerPortalScreen> {
  bool _isLoading = false;
  bool _isSyncing = false;
  String _pharmacyName = 'الصيدلية الرئيسية';
  String _licenseKey = '';
  int _pharmacyId = 1;
  int _branchId = 1;
  String _supabaseUrl = '';
  List<TeleConsultation> _consultations = [];

  @override
  void initState() {
    super.initState();
    _loadTenantData();
  }

  Future<void> _loadTenantData() async {
    setState(() => _isLoading = true);
    try {
      final tenant = await LicenseService.getTenantConfig();
      final pId = int.tryParse(tenant.pharmacyId) ?? 1;
      final bId = int.tryParse(tenant.branchId) ?? 1;
      final url = await CloudSyncService.getSupabaseUrl();

      List<TeleConsultation> consultations = [];
      try {
        consultations = await TelePharmacyService.fetchConsultations(customPharmacyId: pId)
            .timeout(const Duration(seconds: 4), onTimeout: () => []);
      } catch (e) {
        debugPrint('Consultations fetch warning: $e');
      }

      if (mounted) {
        setState(() {
          _pharmacyName = tenant.pharmacyName;
          _licenseKey = tenant.licenseKey;
          _pharmacyId = pId;
          _branchId = bId;
          _supabaseUrl = url;
          _consultations = consultations;
        });
      }
    } catch (e) {
      debugPrint('Error loading tenant data in OwnerPortalScreen: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    try {
      final result = await CloudSyncService.triggerFullSync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? '✅ ${result.message} (تمت مزامنة ${result.syncedSales} فاتورة، ${result.syncedMedicines} صنف)'
                : '⚠️ ${result.message}',
          ),
          backgroundColor: result.isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          duration: const Duration(seconds: 4),
        ),
      );
      _loadTenantData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء المزامنة: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showQrDialog() {
    final qrData = 'PHARMAOS#$_pharmacyId#$_licenseKey#$_pharmacyName#$_supabaseUrl';
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: Colors.cyanAccent, size: 28),
              SizedBox(width: 10),
              Text('رمز الاقتران السريع لتطبيق المدير', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'رمز التفعيل: $_licenseKey',
                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'امسح الرمز أو أدخل رمز التفعيل في تطبيق PharmaOS Owner على هاتف المدير للربط الفوري بالسحابة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
              tooltip: 'الدردشة الحية مع المدير',
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.tealAccent),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DesktopLiveChatScreen()),
                );
              },
            ),
            IconButton(
              tooltip: 'تحديث البيانات',
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
                                Row(
                                  children: [
                                    Text(
                                      'الفرع الحالي: #$_branchId • كود الترخيص: $_licenseKey',
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: _licenseKey));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('تم نسخ كود الترخيص'), duration: Duration(seconds: 2)),
                                        );
                                      },
                                      child: const Icon(Icons.copy_rounded, size: 14, color: Colors.cyanAccent),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Row(
                                  children: [
                                    Icon(Icons.security_rounded, color: Colors.greenAccent, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'مزامنة سحابية مؤمنة وفورية عبر Supabase Cloud Relay',
                                      style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: const Icon(Icons.qr_code_rounded, size: 18),
                                label: const Text('رمز الاقتران السريع (QR)'),
                                onPressed: _showQrDialog,
                              ),
                              const SizedBox(height: 8),
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                                  foregroundColor: const Color(0xFF34D399),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: _isSyncing
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent))
                                    : const Icon(Icons.sync_rounded, size: 18),
                                label: Text(_isSyncing ? 'جاري المزامنة...' : 'مزامنة سحابية الآن 🚀'),
                                onPressed: _isSyncing ? null : _triggerManualSync,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // شبكة ميزات الربط المباشر مع المدير
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            icon: Icons.chat_bubble_rounded,
                            color: const Color(0xFF0D9488),
                            title: 'الدردشة الحية مع المدير',
                            subtitle: 'محادثة فورية ورسائل صوتية وصور مع هاتف المدير',
                            buttonText: 'فتح نافذة المحادثة',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DesktopLiveChatScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickActionCard(
                            icon: Icons.send_rounded,
                            color: const Color(0xFF6366F1),
                            title: 'إرسال روشتة أو استشارة',
                            subtitle: 'إرفاق صورة روشتة لمدير الصيدلية لقراءتها وتحديد الدواء',
                            buttonText: 'إرسال استشارة جديدة',
                            onTap: () => TeleConsultationDialog.show(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickActionCard(
                            icon: Icons.videocam_rounded,
                            color: const Color(0xFFE11D48),
                            title: 'بث الشاشة والكاميرا للمدير',
                            subtitle: 'بث حي ومباشر لشاشة الكاشير وكاميرا الصيدلية للمدير',
                            buttonText: OwnerLiveSyncService.isScreenStreamingActive ? 'البث نشط 🟢' : 'تشغيل البث السحابي',
                            onTap: () {
                              if (OwnerLiveSyncService.isScreenStreamingActive) {
                                OwnerLiveSyncService.stopScreenLiveStream();
                              } else {
                                OwnerLiveSyncService.startScreenLiveStream();
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

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
                                'كيفية ربط تطبيق هاتف المدير (Android / iOS):',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildInstructionStep('1', 'افتح تطبيق PharmaOS Owner على هاتف المدير (أندرويد أو آيفون).'),
                          _buildInstructionStep('2', 'أدخل رمز التفعيل ($_licenseKey) أو امسح رمز الـ QR أعلاه للدخول الفوري.'),
                          _buildInstructionStep('3', 'يصل إشعار سحابي فوري للمدير عند إرفاق أي روشتة أو عند تسجيل مبيعات جديدة.'),
                          _buildInstructionStep('4', 'يرد المدير باسم العلاج والجرعة أو يغير الأسعار أو يراقب البث المباشر والكاميرا لحظياً من أي مكان.'),
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
                          child: Text('لا توجد استشارات معلقة حالياً - النظام متصل وجاهز للاستقبال', style: TextStyle(color: Colors.grey)),
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

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: color.withOpacity(0.2),
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onTap,
              child: Text(buttonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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
