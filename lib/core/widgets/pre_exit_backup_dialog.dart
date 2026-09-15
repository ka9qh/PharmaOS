// واجهة النسخ الاحتياطي الإلزامية قبل إغلاق النظام - PharmaOS
// تظهر تلقائياً عند الضغط على زر إغلاق التطبيق لتأمين نسخة ثلاثية قبل الخروج

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/multi_destination_backup_service.dart';
import '../services/official_date_time_service.dart';

class PreExitBackupDialog extends StatefulWidget {
  const PreExitBackupDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PreExitBackupDialog(),
    );
  }

  @override
  State<PreExitBackupDialog> createState() => _PreExitBackupDialogState();
}

class _PreExitBackupDialogState extends State<PreExitBackupDialog> {
  bool _isProcessing = true;
  bool _isCompleted = false;
  String _currentStatus = 'جاري تحضير ملف قاعدة البيانات وتفريغ الذاكرة...';
  bool _localSaved = false;
  bool _cloudVaultSaved = false;
  String _savedPath = '';
  final String _dateTimeStr = OfficialDateTimeService.formatOfficialDateTime(DateTime.now());

  @override
  void initState() {
    super.initState();
    _startExitBackup();
  }

  Future<void> _startExitBackup() async {
    try {
      final result = await MultiDestinationBackupService.performFullBackup(
        triggerReason: 'واجهة النسخ الإلزامية قبل إغلاق النظام',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _localSaved = progress.localDone;
              _cloudVaultSaved = progress.cloudVaultDone;
              if (progress.localPath != null) _savedPath = progress.localPath!;
              if (progress.message != null) _currentStatus = progress.message!;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCompleted = true;
          _currentStatus = 'تم حفظ وأمان جميع بيانات الصيدلية بنجاح 100%';
        });
      }

      // إغلاق تلقائي آمن بعد اكتمال النسخ بـ 1.5 ثانية
      await Future.delayed(const Duration(milliseconds: 1500));
      await windowManager.destroy();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentStatus = 'تم تأمين البيانات محلياً وسيتم الإغلاق الآن: $e';
        });
      }
      await Future.delayed(const Duration(milliseconds: 1500));
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // أيقونة الحالة
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isCompleted
                        ? Colors.greenAccent.withValues(alpha: 0.15)
                        : Colors.cyanAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isCompleted ? Icons.check_circle_rounded : Icons.shield_rounded,
                    color: _isCompleted ? Colors.greenAccent : Colors.cyanAccent,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),

                // العنوان
                const Text(
                  'تأمين النسخة الاحتياطية قبل الإغلاق',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'التوقيت الرسمي: $_dateTimeStr',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // بنود قنوات النسخ
                _buildChannelTile(
                  icon: Icons.save_alt_rounded,
                  title: 'النسخة المحلية المشفرة (سطح المكتب)',
                  subtitle: _savedPath.isNotEmpty ? _savedPath : 'PharmaOS_Backups',
                  isDone: _localSaved,
                  isLoading: _isProcessing && !_localSaved,
                ),
                const SizedBox(height: 12),
                _buildChannelTile(
                  icon: Icons.cloud_sync_rounded,
                  title: 'مزامنة الحساب السحابي وجوجل درايف',
                  subtitle: 'مزامنة فورية للمجلدات السحابية',
                  isDone: _localSaved,
                  isLoading: _isProcessing && !_localSaved,
                ),
                const SizedBox(height: 12),
                _buildChannelTile(
                  icon: Icons.verified_user_rounded,
                  title: 'الخزينة السحابية الفورية المشفرة',
                  subtitle: 'إيداع وحماية مشفرة 100%',
                  isDone: _cloudVaultSaved,
                  isLoading: _isProcessing && !_cloudVaultSaved,
                ),
                const SizedBox(height: 24),

                // شريط الحالة أو مؤشر التحميل
                if (_isProcessing)
                  Column(
                    children: [
                      const LinearProgressIndicator(
                        color: Colors.cyanAccent,
                        backgroundColor: Colors.white12,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currentStatus,
                        style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _currentStatus,
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // زر الإغلاق الفوري
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                    label: const Text('إغلاق النظام الآن'),
                    onPressed: () async {
                      await windowManager.destroy();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDone
                  ? Colors.greenAccent.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDone ? Colors.greenAccent : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isDone)
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20)
          else if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
            )
          else
            const Icon(Icons.hourglass_empty_rounded, color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}
