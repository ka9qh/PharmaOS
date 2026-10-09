import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/licensing/hardware_id_generator.dart';
import '../../../../core/services/device_branch_manager_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/password_hasher.dart';
import '../../../../core/services/license_service.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../settings/domain/repositories/settings_repository.dart';

class SecureActivationTokensCard extends StatefulWidget {
  const SecureActivationTokensCard({super.key});

  @override
  State<SecureActivationTokensCard> createState() => _SecureActivationTokensCardState();
}

class _SecureActivationTokensCardState extends State<SecureActivationTokensCard> {
  bool _isUnlocked = false;
  bool _isLoading = false;

  String _pharmacyName = 'صيدلية نموذجية';
  String _pharmacyId = '2';
  String _branchId = '2';
  String _licenseType = 'single';
  String _hardwareId = 'LOADING...';
  String _activationRequestCode = '';
  String _licenseKey = 'PHARMAOS-COMMERCIAL-LIFETIME';

  // قائمة أجهزة هاتف المدير المتصلة
  List<Map<String, dynamic>> _linkedOwnerDevices = [];
  bool _isLoadingDevices = false;

  @override
  void initState() {
    super.initState();
    _loadProtectedData();
  }

  Future<void> _loadProtectedData() async {
    setState(() => _isLoading = true);
    try {
      final settingsRepo = sl<SettingsRepository>();
      final settings = await settingsRepo.load();
      final hwId = await HardwareIdGenerator.getHardwareId();
      final pName = settings.pharmacyName.isNotEmpty ? settings.pharmacyName : 'صيدلية نموذجية';
      final reqCode = await DeviceBranchManagerService.generatePharmacyActivationRequestCode(pName, hwId);
      final tenantConfig = await LicenseService.getTenantConfig();

      if (mounted) {
        setState(() {
          _pharmacyName = pName;
          _pharmacyId = tenantConfig.pharmacyId.isNotEmpty ? tenantConfig.pharmacyId : '2';
          _branchId = tenantConfig.branchId.isNotEmpty ? tenantConfig.branchId : '2';
          _licenseType = tenantConfig.licenseType;
          _hardwareId = hwId;
          _activationRequestCode = reqCode;
          _licenseKey = tenantConfig.licenseKey.isNotEmpty ? tenantConfig.licenseKey : 'PHARMAOS-COMMERCIAL-LIFETIME';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// جلب قائمة الهواتف المتصلة مباشرة من سيرفر Supabase
  Future<void> _loadLinkedOwnerDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();

      final response = await http
          .get(
            Uri.parse('$supabaseUrl/rest/v1/branches?pharmacy_id=eq.$_pharmacyId&select=*&order=created_at.desc'),
            headers: {
              'apikey': apiKey,
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          // فلترة الأجهزة التي تم ربطها عبر تطبيق المدير
          final devices = data.where((b) {
            final key = b['branch_activation_key']?.toString() ?? '';
            final name = b['name']?.toString() ?? '';
            return key.startsWith('OWNER-') || name.contains('هاتف المدير');
          }).map((e) => Map<String, dynamic>.from(e)).toList();

          if (mounted) {
            setState(() {
              _linkedOwnerDevices = devices;
              _isLoadingDevices = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading linked owner devices: $e');
    }
    if (mounted) setState(() => _isLoadingDevices = false);
  }

  /// إيقاف أو تفعيل جهاز المدير عن بعد في Supabase
  Future<void> _toggleDeviceStatus(Map<String, dynamic> device) async {
    final deviceId = device['id'];
    final currentStatus = device['is_active'] == true;
    final newStatus = !currentStatus;

    try {
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();

      final res = await http
          .patch(
            Uri.parse('$supabaseUrl/rest/v1/branches?id=eq.$deviceId'),
            headers: {
              'apikey': apiKey,
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'is_active': newStatus}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _loadLinkedOwnerDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus ? 'تم تفعيل الجهاز بنجاح 🟢' : 'تم إيقاف الجهاز وتعطيل وصوله بنجاح ⛔'),
              backgroundColor: newStatus ? const Color(0xFF10B981) : Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تعديل حالة الجهاز: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  /// حذف جهاز مقترن
  Future<void> _deleteLinkedDevice(Map<String, dynamic> device) async {
    final deviceId = device['id'];
    final deviceName = device['name'] ?? 'هاتف المدير';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('تأكيد حذف الاقتران', style: TextStyle(color: Colors.white)),
          content: Text('هل أنت متأكد من رغبتك في حذف اقتران ($deviceName) نهائياً من النظام؟', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف الاقتران'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final supabaseUrl = await CloudSyncService.getSupabaseUrl();
        final apiKey = await CloudSyncService.getSupabaseAnonKey();

        await http.delete(
          Uri.parse('$supabaseUrl/rest/v1/branches?id=eq.$deviceId'),
          headers: {
            'apikey': apiKey,
            'Authorization': 'Bearer $apiKey',
          },
        ).timeout(const Duration(seconds: 8));

        await _loadLinkedOwnerDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف اقتران الجهاز بنجاح'), backgroundColor: Colors.teal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر الحذف: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  /// نافذة طلب كلمة مرور المدير للتحقق الأمني الصارم
  Future<void> _promptManagerAuth() async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    String? errorText;

    final authenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 10),
                const Text(
                  'تأكيد هوية المدير 🔐',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'لحماية ترخيص النظام وبيانات الربط المباشر ومنع التلاعب، الرجاء إدخال كلمة مرور حساب المدير العام:',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'كلمة مرور المدير',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    errorText: errorText,
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  onSubmitted: (_) async {
                    // Trigger authentication
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('تأكيد وعرض البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final entered = passwordCtrl.text.trim();
                  if (entered.isEmpty) {
                    setDialogState(() => errorText = 'الرجاء إدخال كلمة المرور');
                    return;
                  }

                  // التحقق الصارم من جدول المستخدمين في SQLite (حسابات المدير أو المالك)
                  try {
                    final db = sl<AppDatabase>();
                    final users = await db.select(db.users).get();
                    bool matched = false;

                    final adminUsers = users.where((u) => u.role == 'owner' || u.role == 'admin').toList();

                    if (adminUsers.isEmpty) {
                      // إذا لم يتم إنشاء مستخدمين بعد في أول تشغيل، نسمح بالمرور
                      matched = true;
                    } else {
                      for (final u in adminUsers) {
                        if (PasswordHasher.verify(entered, u.passwordHash)) {
                          matched = true;
                          break;
                        }
                      }
                    }

                    if (matched) {
                      Navigator.pop(ctx, true);
                      return;
                    }
                  } catch (_) {}

                  setDialogState(() => errorText = 'كلمة المرور غير صحيحة! تم رفض الوصول.');
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (authenticated == true && mounted) {
      setState(() => _isUnlocked = true);
      _loadLinkedOwnerDevices();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التحقق بنجاح! تم إظهار بيانات الترخيص ورمز باركود الربط.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label إلى الحافظة بنجاح 📋'),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// باركود الاقتران والاتصال الذكي الشامل لتطبيق المدير
  String _getQrCodePayload() {
    return jsonEncode({
      'app': 'pharmaos_owner',
      'pharmacy_id': int.tryParse(_pharmacyId) ?? 2,
      'branch_id': int.tryParse(_branchId) ?? 1,
      'pharmacy_name': _pharmacyName,
      'license_key': _licenseKey,
      'license_type': _licenseType,
      'supabase_url': CloudSyncService.defaultSupabaseUrl,
      'supabase_key': CloudSyncService.defaultSupabaseAnonKey,
    });
  }

  void _showQrDialog(String code, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 240,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'امسح هذا الباركود باستخدام تطبيق المدير (PharmaOS Owner) على هاتفك للربط الفوري التلقائي دون الحاجة لكتابة أي بيانات.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('نسخ كود الترخيص'),
              onPressed: () {
                _copyToClipboard(_licenseKey, 'كود الترخيص');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrPayload = _getQrCodePayload();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isUnlocked ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFF3B82F6).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isUnlocked ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: _isUnlocked ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بيانات ترخيص الصيدلية وباركود الاقتران المحمي',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _isUnlocked
                          ? 'مفتوح - تم التحقق من صلاحية المدير (عرض ونسخ فقط)'
                          : 'محمي ومقفل - يتطلب إدخال كلمة مرور المدير',
                      style: TextStyle(
                        color: _isUnlocked ? const Color(0xFF10B981) : Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUnlocked)
                IconButton(
                  tooltip: 'إعادة القفل والإخفاء',
                  icon: const Icon(Icons.lock_outline_rounded, color: Colors.amber),
                  onPressed: () => setState(() => _isUnlocked = false),
                ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 8),
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(minHeight: 2, color: Color(0xFF10B981), backgroundColor: Colors.white10),
            ),
          ],
          const SizedBox(height: 14),

          if (!_isUnlocked) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildMaskedRow('اسم الصيدلية المعتمد'),
                  const SizedBox(height: 10),
                  _buildMaskedRow('معرف الصيدلية (Pharmacy ID)'),
                  const SizedBox(height: 10),
                  _buildMaskedRow('مفتاح الترخيص السحابي (License Key)'),
                  const SizedBox(height: 10),
                  _buildMaskedRow('باركود اقتران هاتف المدير السحابي (QR Code)'),
                  const SizedBox(height: 10),
                  _buildMaskedRow('الأجهزة المتصلة بتطبيق المدير (Linked Devices)'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.password_rounded, size: 20),
                label: const Text(
                  'كتابة كلمة مرور المدير لعرض البيانات والباركود 🔐',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _promptManagerAuth,
              ),
            ),
          ] else ...[
            // الحالة المفتوحة: عرض باركود / QR Code الاقتران الفوري
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 100,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'باركود اتصال واقتران تطبيق المدير 📲',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'افتح تطبيق المدير على هاتفك واضغط على زر "تصوير باركود الاتصال" لمسح هذا الرمز والاتصال بالنظام فوراً دون أي إدخال.',
                          style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.fullscreen_rounded, size: 16),
                          label: const Text('تكبير الباركود للمسح', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showQrDialog(qrPayload, 'باركود اتصال تطبيق المدير'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // عرض جميع بيانات الترخيص مع أزرار النسخ (للقراءة فقط دون تعديل)
            _buildRevealedCard(
              title: 'اسم الصيدلية المعتمد',
              subtitle: 'الاسم المسجل رسمياً في الترخيص السحابي',
              value: _pharmacyName,
              icon: Icons.storefront_rounded,
              color: Colors.white,
            ),
            const SizedBox(height: 10),
            _buildRevealedCard(
              title: 'معرف الصيدلية السحابي (Pharmacy ID)',
              subtitle: 'المعرف الرقمي الثابت للصيدلية على السيرفر',
              value: _pharmacyId,
              icon: Icons.tag_rounded,
              color: const Color(0xFF38BDF8),
            ),
            const SizedBox(height: 10),
            _buildRevealedCard(
              title: 'رمز تفعيل الصيدلية والترخيص (License Key)',
              subtitle: 'مفتاح الترخيص الدائم المشفر',
              value: _licenseKey,
              icon: Icons.vpn_key_rounded,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 10),
            _buildRevealedCard(
              title: 'نوع الترخيص وسماحية الفروع (License Type)',
              subtitle: _licenseType == 'multi_branch'
                  ? 'ترخيص يدعم إنشاء فروع إضافية متزامنة ورموز تفعيل لكل فرع'
                  : 'ترخيص صيدلية فردية مقفل (لا يسمح بإنشاء أي فروع إضافية)',
              value: _licenseType == 'multi_branch' ? 'صيدلية متعددة الفروع (Multi-Branch)' : 'صيدلية فردية (Single Pharmacy 🔒)',
              icon: _licenseType == 'multi_branch' ? Icons.account_tree_rounded : Icons.store_mall_directory_rounded,
              color: _licenseType == 'multi_branch' ? const Color(0xFF10B981) : Colors.amber,
            ),
            const SizedBox(height: 10),
            _buildRevealedCard(
              title: 'معرف الجهاز الحصري (Hardware Fingerprint)',
              subtitle: 'المعرف المادي الحصري الخاص بهذا الجهاز لمنع الاستنساخ',
              value: _hardwareId,
              icon: Icons.memory_rounded,
              color: Colors.purpleAccent,
            ),
            const SizedBox(height: 10),
            _buildRevealedCard(
              title: 'حالة الترخيص والتشغيل',
              subtitle: 'الترخيص رسمي ونشط ومفعل مدى الحياة لهذا النظام',
              value: 'نشط مدى الحياة (Lifetime Licensed)',
              icon: Icons.verified_user_rounded,
              color: const Color(0xFF10B981),
            ),
            if (_activationRequestCode.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildRevealedCard(
                title: 'رمز طلب الترخيص والتفعيل (Activation Request Code)',
                subtitle: 'الرمز الفني الخاص بهذا الجهاز لإصدار التراخيص',
                value: _activationRequestCode,
                icon: Icons.pin_rounded,
                color: Colors.orangeAccent,
              ),
            ],

            const SizedBox(height: 16),

            // جدول الأجهزة المتصلة بتطبيق المدير (Linked Devices) مع إمكانية الإيقاف
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phone_android_rounded, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'الهواتف والأجهزة المقترنة بتطبيق المدير:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'تحديث قائمة الأجهزة',
                  icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent, size: 18),
                  onPressed: _loadLinkedOwnerDevices,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoadingDevices)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.cyanAccent)))
            else if (_linkedOwnerDevices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Text(
                  'لا توجد هواتف مقترنة حالياً. عند مسح الباركود أعلاه من تطبيق المدير، سيظهر الجهاز هنا مع كامل بياناته.',
                  style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._linkedOwnerDevices.map((dev) => _buildLinkedDeviceTile(dev)),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('إعادة قفل وإخفاء الرموز فوراً 🔒', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => setState(() => _isUnlocked = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkedDeviceTile(Map<String, dynamic> dev) {
    final name = dev['name']?.toString() ?? 'هاتف المدير';
    final osInfo = dev['branch_device_fingerprint']?.toString() ?? 'غير معروف';
    final isActive = dev['is_active'] == true;
    final createdAt = dev['created_at']?.toString() ?? '';
    final lastSync = dev['last_sync_at']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF10B981).withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF10B981).withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smartphone_rounded,
              color: isActive ? const Color(0xFF10B981) : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? 'نشط ومتصل 🟢' : 'موقوف من المدير 🔴',
                        style: TextStyle(
                          color: isActive ? const Color(0xFF34D399) : Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'النظام: $osInfo | الاقتران: ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}${lastSync.isNotEmpty ? ' | مزامنة: ${lastSync.length >= 16 ? lastSync.substring(11, 16) : lastSync}' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // زر الإيقاف أو إعادة التفعيل
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: isActive ? Colors.redAccent.withOpacity(0.2) : Colors.green.withOpacity(0.2),
              foregroundColor: isActive ? Colors.redAccent : Colors.greenAccent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _toggleDeviceStatus(dev),
            child: Text(
              isActive ? 'إيقاف الجهاز ⛔' : 'إعادة التفعيل 🟢',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'حذف الاقتران',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
            onPressed: () => _deleteLinkedDevice(dev),
          ),
        ],
      ),
    );
  }

  Widget _buildMaskedRow(String label) {
    return Row(
      children: [
        const Icon(Icons.lock_outline, color: Colors.grey, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        const Text(
          '••••••••••••••••',
          style: TextStyle(color: Color(0xFF64748B), letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRevealedCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                tooltip: 'نسخ',
                onPressed: () => _copyToClipboard(value, title),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}
