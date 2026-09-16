// تبويب إعدادات الصيدلية وتعدد الفروع - PharmaOS Owner App
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/owner_api_service.dart';
import '../services/app_updater_service.dart';
import 'login_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  OwnerTenantConfig? _config;
  bool _isCheckingUpdate = false;
  OwnerAppUpdateInfo? _availableUpdate;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _checkSilentUpdate();
  }

  Future<void> _loadConfig() async {
    final cfg = await OwnerApiService.getConfig();
    if (mounted) setState(() => _config = cfg);
  }

  Future<void> _checkSilentUpdate() async {
    final update = await AppUpdaterService.checkForUpdates();
    if (mounted && update != null) {
      setState(() => _availableUpdate = update);
    }
  }

  Future<void> _handleManualCheckUpdate() async {
    setState(() => _isCheckingUpdate = true);
    final update = await AppUpdaterService.checkForUpdates();
    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
        _availableUpdate = update;
      });

      if (update != null) {
        AppUpdaterService.showUpdateDialog(context, update);
      } else {
        AppUpdaterService.showNoUpdateDialog(context);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
          content: const Text('هل تريد تسجيل الخروج وفصل ربط الصيدلية الحالية؟', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      await OwnerApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('إعدادات الصيدلية والترخيص', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة بيانات الصيدلية المعزولة
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.store_rounded, color: Colors.cyanAccent, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _config?.pharmacyName ?? 'صيدليتي',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'كود الصيدلية الموحد: #${_config?.pharmacyId ?? 1}',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.person_rounded, 'المدير المسؤول', _config?.managerName ?? 'المدير العام'),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.cloud_done_rounded, 'السيرفر السحابي', 'Supabase Cloud (Active)'),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.security_rounded, 'أمان البيانات', 'عزل تام RLS 100%'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // بطاقة التحديثات التلقائية والاتصال بـ GitHub
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _availableUpdate != null
                      ? const Color(0xFF10B981).withOpacity(0.5)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _availableUpdate != null
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : const Color(0xFF3B82F6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _availableUpdate != null
                              ? Icons.new_releases_rounded
                              : Icons.system_update_rounded,
                          color: _availableUpdate != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFF60A5FA),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تحديثات التطبيق والنظام',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'الإصدار الحالي: v${AppUpdaterService.currentVersion} • GitHub Releases',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_availableUpdate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'تحديث جديد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_availableUpdate != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF10B981),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'متوفر الإصدار v${_availableUpdate!.version} (${_availableUpdate!.releaseDate})',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _availableUpdate!.changelogAr.isNotEmpty
                                ? _availableUpdate!.changelogAr.first
                                : 'يتضمن تحديثات وميزات جديدة ومزامنة فورية.',
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isCheckingUpdate
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: Text(
                            _isCheckingUpdate
                                ? 'جاري الفحص...'
                                : 'فحص التحديثات الآن',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: _isCheckingUpdate ? null : _handleManualCheckUpdate,
                        ),
                      ),
                      if (_availableUpdate != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.download_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'تحديث وتنزيل',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => AppUpdaterService.showUpdateDialog(
                              context,
                              _availableUpdate!,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // معلومات النظام والنسخة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حول PharmaOS Owner',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'الإصدار 1.0.0+1 - نظام متكامل لمتابعة الصيدليات المتعددة، الرقابة اللحظية، فواتير المشتريات، وجداول الأدوية، وغرفة الاستشارات الطبية والروشتات اللحظية مع التحديث التلقائي عبر GitHub.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade900.withOpacity(0.4),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'تسجيل الخروج من الحساب',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}
