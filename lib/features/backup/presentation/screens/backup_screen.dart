// شاشة الحماية والربط المباشر مع Google Drive واستعادة البيانات - PharmaOS
// تدعم ربط حساب جوجل درايف والرفع التلقائي للنسخ كل 24 ساعة وعند إغلاق اليومية
// مع إمكانية فتح جوجل درايف بالمتصفح بضغطة زر وتحميل النسخة واستعادتها في أي وقت.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/backup_provider.dart';
import '../widgets/backup_widget.dart';
import '../../../../core/services/cloud_backup_service.dart';
import '../../../../core/services/google_drive_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _gmailCtrl = TextEditingController();
  bool _isDriveConnected = false;
  String _connectedGmail = '';
  String _lastDriveUpload = 'لم يتم بعد';

  bool _isConnectingDrive = false;
  bool _isUploadingDrive = false;
  bool _isExportingLocal = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadGoogleDriveInfo();
  }

  @override
  void dispose() {
    _gmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGoogleDriveInfo() async {
    final driveInfo = await GoogleDriveService.getDriveInfo();
    if (mounted) {
      setState(() {
        _isDriveConnected = driveInfo['isConnected'] ?? false;
        _connectedGmail = driveInfo['email'] ?? '';
        _lastDriveUpload = driveInfo['lastUpload'] ?? 'لم يتم بعد';
        if (_connectedGmail.isNotEmpty) {
          _gmailCtrl.text = _connectedGmail;
        }
      });
    }
  }

  Future<void> _connectGoogleDrive() async {
    final email = _gmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال بريد جوجل (Gmail) صحيح للربط.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isConnectingDrive = true);
    final result = await GoogleDriveService.connectGoogleAccount(email: email);
    setState(() => _isConnectingDrive = false);

    if (mounted) {
      await _loadGoogleDriveInfo();
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(result.success ? Icons.cloud_done : Icons.error_outline,
                    color: result.success ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(result.success ? 'تم ربط Google Drive بنجاح' : 'خطأ في الربط'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message, style: const TextStyle(fontSize: 14, height: 1.5)),
                const SizedBox(height: 12),
                const Text(
                  '💡 أصبحت صيدليتك مربوطة بالكامل مع Google Drive، وسيتم رفع نسخة أمان تلقائياً كل 24 ساعة وعند إغلاق اليومية.',
                  style: TextStyle(fontSize: 12, color: Colors.teal),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً، رائع'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _uploadToDriveNow() async {
    setState(() => _isUploadingDrive = true);
    final file = await CloudBackupService.createPharmacyBackupFile();
    final result = await GoogleDriveService.uploadToGoogleDrive(backupFile: file);
    setState(() => _isUploadingDrive = false);

    if (mounted) {
      await _loadGoogleDriveInfo();
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(result.success ? Icons.cloud_done : Icons.error_outline,
                    color: result.success ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(result.success ? 'نجاح الرفع إلى Google Drive' : 'تنبيه الاتصال'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message, style: const TextStyle(fontSize: 14, height: 1.5)),
                if (result.backupFile != null) ...[
                  const SizedBox(height: 12),
                  const Text('تم حفظ نسخة محلية أيضاً في:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  SelectableText(result.backupFile!.path, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                ],
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.open_in_browser),
                label: const Text('فتح Google Drive بالمتصفح'),
                onPressed: () {
                  Navigator.pop(ctx);
                  GoogleDriveService.openGoogleDriveInBrowser();
                },
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _disconnectGoogleDrive() async {
    await GoogleDriveService.disconnectGoogleAccount();
    await _loadGoogleDriveInfo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء ربط حساب Google Drive.'), backgroundColor: Colors.blueGrey),
      );
    }
  }

  Future<void> _exportLocalBackup() async {
    setState(() => _isExportingLocal = true);
    try {
      final file = await CloudBackupService.createPharmacyBackupFile();
      if (mounted) {
        setState(() => _isExportingLocal = false);
        ref.read(backupNotifierProvider.notifier).loadAll();
        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.shield, color: Colors.green),
                  SizedBox(width: 8),
                  Text('تم إنشاء نسخة الأمان بنجاح'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تم حفظ نسخة صيدليتك بنجاح على سطح المكتب:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText(file.path, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  const Text(
                    '💡 نصيحة أمان: يمكنك إرسال هذا الملف إلى بريدك الإلكتروني أو الواتساب لحفظ بيانات صيدليتك للأبد.',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('فهمت، حسناً'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExportingLocal = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء النسخة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRestoreDialog() {
    final pathCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.restore, color: Colors.orange),
              SizedBox(width: 8),
              Text('استعادة بيانات الصيدلية من ملف نسخة سابقة'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ تنبيه: استعادة النسخة الاحتياطية ستقوم بتحديث واسترجاع كافة الأدوية والفواتير والديون من ملف النسخة وتطبيقها فوراً.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pathCtrl,
                  decoration: const InputDecoration(
                    labelText: 'مسار ملف النسخة الاحتياطية (.pharmaos_backup أو .sqlite)',
                    hintText: 'C:\\Users\\...\\نسخة_أمان_صيدليتي.pharmaos_backup',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text('تأكيد الاستعادة الفورية'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final path = pathCtrl.text.trim();
                if (path.isEmpty || !File(path).existsSync()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('مسار الملف غير صحيح أو الملف غير موجود'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _isRestoring = true);
                final ok = await CloudBackupService.restoreDatabase(path);
                setState(() => _isRestoring = false);

                if (mounted) {
                  if (ok) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (alertCtx) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.verified, color: Colors.green),
                              SizedBox(width: 8),
                              Text('تمت الاستعادة بنجاح 100%'),
                            ],
                          ),
                          content: const Text(
                            'تمت استعادة كافة بيانات الصيدلية، الأدوية، الفواتير، والديون بنجاح تام.\n'
                            'يرجى إعادة تشغيل النظام لتطبيق قاعدة البيانات المستعادة بالكامل.',
                          ),
                          actions: [
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(alertCtx);
                                exit(0);
                              },
                              child: const Text('إغلاق وإعادة التشغيل الآن'),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('حدث خطأ أثناء الاستعادة'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('النسخ السحابي والربط مع Google Drive'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () {
                _loadGoogleDriveInfo();
                ref.read(backupNotifierProvider.notifier).loadAll();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- بطاقة ربط Google Drive ----------------
              _isDriveConnected ? _buildConnectedDriveCard() : _buildConnectDriveCard(),

              const SizedBox(height: 18),

              // ---------------- كيف تعمل الحماية ----------------
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_done_outlined, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('كيف تصل لنسخك من أي هاتف أو كمبيوتر عبر Google Drive؟',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        '1️⃣ بمجرد ربط حسابك في Google Drive، يرفع النظام نسخة أمان تلقائياً كل 24 ساعة وعند إغلاق اليومية.\n'
                        '2️⃣ في حال احتراق المحل أو تلف الكمبيوتر: افتح drive.google.com من أي جوال أو لابتوب ونزل ملف النسخة الاحتياطية.\n'
                        '3️⃣ افتح البرنامج على أي جهاز جديد واضغط "استعادة البيانات" لتسترجع كافة الأدوية والفواتير والديون في ثانية واحدة.',
                        style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ---------------- سجل النسخ المحلية ----------------
              const Text('سجل النسخ الاحتياطية المحلية على هذا الجهاز:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),

              state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.backups.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  const Text('لا توجد نسخ مسجلة بعد. اضغط على "تصدير نسخة لسطح المكتب" لإنشاء نسخة.'),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.backups.length,
                          itemBuilder: (context, index) => BackupFileTile(backup: state.backups[index]),
                        ),
            ],
          ),
        ),
      ),
    );
  }

  // بطاقة ربط Google Drive (إذا لم يكن مربوطاً)
  Widget _buildConnectDriveCard() {
    return Card(
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_to_drive, color: Colors.lightBlueAccent, size: 32),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ربط حساب Google Drive السحابي (Google Cloud Sync)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text(
                        'اربط حسابك في Google لرفع نسخ الأمان تلقائياً كل 24 ساعة وعند إغلاق اليومية إلى درايف.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 28),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gmailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'بريد حساب جوجل درايف (Gmail / Google Account)',
                      labelStyle: const TextStyle(color: Colors.lightBlueAccent),
                      hintText: 'your.pharmacy@gmail.com',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.lightBlueAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  icon: _isConnectingDrive
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.link),
                  label: const Text('🔗 تسجيل الدخول والربط بحساب Google Drive الآن'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isConnectingDrive ? null : _connectGoogleDrive,
                ),
                FilledButton.tonalIcon(
                  icon: _isExportingLocal
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.desktop_windows),
                  label: const Text('تصدير نسخة لسطح المكتب'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  onPressed: _isExportingLocal ? null : _exportLocalBackup,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restore, color: Colors.orangeAccent),
                  label: const Text('استعادة البيانات من نسخة سابقة', style: TextStyle(color: Colors.orangeAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orangeAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showRestoreDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // بطاقة Google Drive المربوط والنشط
  Widget _buildConnectedDriveCard() {
    return Card(
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_to_drive, color: Colors.lightBlueAccent, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('حساب Google Drive متصل ونشط',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('🟢 مزامنة Google Drive مفعلة', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الحساب المتصل: $_connectedGmail',
                        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.lightBlueAccent, size: 18),
                    SizedBox(width: 6),
                    Text('الرفع التلقائي إلى Google Drive يعمل كل 24 ساعة وعند إغلاق اليومية',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                Text('آخر رفع إلى درايف: $_lastDriveUpload', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  icon: _isUploadingDrive
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload),
                  label: const Text('رفع نسخة إلى Google Drive الآن ☁️'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isUploadingDrive ? null : _uploadToDriveNow,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('فتح Google Drive لتحميل النسخ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: GoogleDriveService.openGoogleDriveInBrowser,
                ),
                FilledButton.tonalIcon(
                  icon: _isExportingLocal
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.desktop_windows),
                  label: const Text('تصدير نسخة لسطح المكتب'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  onPressed: _isExportingLocal ? null : _exportLocalBackup,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restore, color: Colors.orangeAccent),
                  label: const Text('استعادة البيانات من نسخة سابقة', style: TextStyle(color: Colors.orangeAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orangeAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showRestoreDialog,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.link_off, color: Colors.redAccent, size: 18),
                  label: const Text('إلغاء ربط Google Drive', style: TextStyle(color: Colors.redAccent)),
                  onPressed: _disconnectGoogleDrive,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
