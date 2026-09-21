// ودجت التحقق من التحديثات وإدارة الترخيص والفروع - PharmaOS Settings
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/models/app_update_info.dart';
import '../../../../core/models/tenant_config.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/services/license_service.dart';

class UpdateCheckerCard extends StatefulWidget {
  const UpdateCheckerCard({super.key});

  @override
  State<UpdateCheckerCard> createState() => _UpdateCheckerCardState();
}

class _UpdateCheckerCardState extends State<UpdateCheckerCard> {
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _statusMessage;
  AppUpdateInfo? _availableUpdate;
  TenantConfig? _tenantConfig;

  @override
  void initState() {
    super.initState();
    _loadTenantConfig();
  }

  Future<void> _loadTenantConfig() async {
    final config = await LicenseService.getTenantConfig();
    if (mounted) setState(() => _tenantConfig = config);
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'جاري التحقق من وجود إصدارات جديدة...';
      _availableUpdate = null;
    });

    try {
      final update = await UpdateService.checkForUpdates();
      if (!mounted) return;

      setState(() {
        _isChecking = false;
        if (update != null) {
          _availableUpdate = update;
          _statusMessage = '🚀 إصدار جديد متوفر: v${update.version}';
          _showUpdateDialog(update);
        } else {
          _statusMessage = '✓ النظام محدث لآخر إصدار متوفر (v${UpdateService.currentVersion})';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _statusMessage = 'تعذر الاتصال بخادم التحديثات. تأكد من اتصال الإنترنت.';
        });
      }
    }
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.system_update_alt_rounded, color: Colors.green.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تحديث جديد متاح v${update.version}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('تاريخ الإصدار: ${update.releaseDate}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الميزات والتحسينات الجديدة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        update.changelogArabic,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 20, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'أمان 100%: سيتم أخذ نسخة احتياطية من قاعدة البيانات تلقائياً قبل بدء التحديث.',
                              style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isDownloading) ...[
                      const SizedBox(height: 16),
                      Text('جاري تنزيل التحديث: ${(_downloadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: _downloadProgress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!_isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('لاحقاً'),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade800),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(_isDownloading ? 'جاري التثبيت...' : 'تثبيت التحديث الآن 🚀'),
                  onPressed: _isDownloading
                      ? null
                      : () async {
                          setDialogState(() => _isDownloading = true);
                          setState(() => _isDownloading = true);

                          final zip = await UpdateService.downloadUpdatePackage(
                            update,
                            onProgress: (p) {
                              setDialogState(() => _downloadProgress = p);
                              setState(() => _downloadProgress = p);
                            },
                          );

                          if (zip != null) {
                            await UpdateService.applyUpdateAndRestart(zip);
                          } else {
                            setDialogState(() => _isDownloading = false);
                            if (mounted) {
                              setState(() => _isDownloading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('فشل تنزيل التحديث. يرجى التحقق من اتصال الإنترنت.')),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLicenseDialog() {
    if (_tenantConfig == null) return;
    final pharmIdCtrl = TextEditingController(text: _tenantConfig!.pharmacyId);
    final pharmNameCtrl = TextEditingController(text: _tenantConfig!.pharmacyName);
    final branchIdCtrl = TextEditingController(text: _tenantConfig!.branchId);
    final branchNameCtrl = TextEditingController(text: _tenantConfig!.branchName);
    final licenseKeyCtrl = TextEditingController(text: _tenantConfig!.licenseKey);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.business_rounded, color: Colors.teal),
              SizedBox(width: 8),
              Text('بيانات ترخيص الصيدلية والفرع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pharmIdCtrl,
                    decoration: const InputDecoration(labelText: 'كود ترخيص الصيدلية (Pharmacy ID)', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pharmNameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم الصيدلية المعتمد', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: branchIdCtrl,
                          decoration: const InputDecoration(labelText: 'كود الفرع (Branch ID)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: branchNameCtrl,
                          decoration: const InputDecoration(labelText: 'اسم الفرع', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: licenseKeyCtrl,
                    decoration: const InputDecoration(labelText: 'مفتاح الترخيص السحابي (License Key)', isDense: true, border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                await LicenseService.activateLicense(
                  licenseKey: licenseKeyCtrl.text,
                  branchActivationKey: branchIdCtrl.text.isNotEmpty ? branchIdCtrl.text : null,
                );
                await _loadTenantConfig();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: Colors.green, content: Text('✓ تم حفظ بيانات الترخيص والفرع بنجاح')),
                  );
                }
              },
              child: const Text('حفظ البيانات'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // كارت التحديثات التلقائية
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.indigo.shade50.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cloud_sync_rounded, color: Colors.indigo.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تحديثات النظام عن بعد (OTA Updates)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'الإصدار المثبت حالياً: v${UpdateService.currentVersion} (Build ${UpdateService.currentBuildNumber})',
                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade800),
                    icon: _isChecking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(_isChecking ? 'جاري الفحص...' : 'التحقق من وجود تحديثات 🔄'),
                    onPressed: _isChecking ? null : _checkForUpdates,
                  ),
                ],
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _availableUpdate != null ? Colors.green.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _availableUpdate != null ? Colors.green.shade200 : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _availableUpdate != null ? Icons.new_releases_rounded : Icons.info_outline,
                        size: 16,
                        color: _availableUpdate != null ? Colors.green.shade800 : Colors.blueGrey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _availableUpdate != null ? Colors.green.shade900 : Colors.blueGrey.shade800,
                          ),
                        ),
                      ),
                      if (_availableUpdate != null)
                        TextButton(
                          onPressed: () => _showUpdateDialog(_availableUpdate!),
                          child: const Text('عرض التفاصيل والتثبيت ⬅️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // كارت معلومات ترخيص الصيدلية وتعدد الفروع
        if (_tenantConfig != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.shade100, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.verified_user_rounded, color: Colors.teal.shade800),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بيانات الترخيص والصيدلية (${_tenantConfig!.pharmacyName})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'معرف الصيدلية: ${_tenantConfig!.pharmacyId} | الفرع: ${_tenantConfig!.branchName} (${_tenantConfig!.branchId}) | الجهاز: ${_tenantConfig!.deviceId}',
                            style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('تعديل الترخيص'),
                      onPressed: _showLicenseDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
