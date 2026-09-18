// بطاقة الخزينة السحابية المشفرة - PharmaOS
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/multi_destination_backup_service.dart';

class TelegramVaultSettingsCard extends StatefulWidget {
  const TelegramVaultSettingsCard({super.key});

  @override
  State<TelegramVaultSettingsCard> createState() => _TelegramVaultSettingsCardState();
}

class _TelegramVaultSettingsCardState extends State<TelegramVaultSettingsCard> {
  final _botTokenController = TextEditingController();
  final _chatIdController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = 'الخزينة السحابية جاهزة ومحمية بالكامل';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final token = await MultiDestinationBackupService.getEffectiveBotToken();
    final chatId = await MultiDestinationBackupService.getEffectiveChatId();
    if (mounted) {
      setState(() {
        _botTokenController.text = token;
        _chatIdController.text = chatId;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MultiDestinationBackupService.prefCustomBotToken, _botTokenController.text.trim());
    await prefs.setString(MultiDestinationBackupService.prefCustomChatId, _chatIdController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ مفاتيح الخزينة السحابية المشفرة بنجاح ✅'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري فحص الاتصال بالخزينة السحابية...';
    });

    final res = await MultiDestinationBackupService.testTelegramConnection(
      customToken: _botTokenController.text.trim(),
      customChatId: _chatIdController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = res['message'] ?? 'اكتمل الفحص';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? ''),
          backgroundColor: res['success'] == true ? const Color(0xFF059669) : Colors.orange.shade800,
        ),
      );
    }
  }

  Future<void> _sendImmediateBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري تحضير قاعدة البيانات وتأمينها سحابياً...';
    });

    final progress = await MultiDestinationBackupService.performFullBackup(
      triggerReason: 'إرسال يدوي فوري من شاشة الإعدادات',
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = progress.cloudVaultDone
            ? 'تم تأمين النسخة الاحتياطية بنجاح في الخزينة السحابية ✅'
            : 'تم حفظ النسخة محلياً (${progress.message})';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_statusMessage),
          backgroundColor: progress.cloudVaultDone ? const Color(0xFF059669) : Colors.orange.shade800,
        ),
      );
    }
  }

  @override
  void dispose() {
    _botTokenController.dispose();
    _chatIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blueGrey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_moon_rounded, color: Color(0xFF0284C7), size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'الخزينة السحابية المشفرة (Cloud Security Vault)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(width: 8),
                          Chip(
                            label: Text('تلقائي مع كل نسخ وعند الإغلاق', style: TextStyle(fontSize: 10, color: Colors.white)),
                            backgroundColor: Color(0xFF0284C7),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      Text(
                        'إرسال تلقائي وفوري لملف النسخة الاحتياطية المشفرة سحابياً لحماية بياناتك من التلف أو السرقة',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _botTokenController,
                          decoration: const InputDecoration(
                            labelText: 'مفتاح أمان الخزينة السحابية (Vault Key)',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.key_rounded, size: 20),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _chatIdController,
                          decoration: const InputDecoration(
                            labelText: 'معرف الخزينة أو القناة المشفرة (Vault ID)',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag_rounded, size: 20),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusMessage.contains('✅') ? const Color(0xFF059669) : Colors.blueGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('حفظ الإعدادات', style: TextStyle(fontSize: 12)),
                        onPressed: _isLoading ? null : _saveSettings,
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        icon: _isLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.verified_outlined, size: 16),
                        label: const Text('فحص الجاهزية 🧪', style: TextStyle(fontSize: 12)),
                        onPressed: _isLoading ? null : _testConnection,
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                        label: const Text('إرسال نسخة فورية 🚀', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _isLoading ? null : _sendImmediateBackup,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
