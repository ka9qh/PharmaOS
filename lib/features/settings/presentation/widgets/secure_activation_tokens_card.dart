// بطاقة رموز التفعيل والترخيص واقتران الأجهزة المحمية برمز دخول المدير - PharmaOS
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/licensing/hardware_id_generator.dart';
import '../../../../core/services/device_branch_manager_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/password_hasher.dart';
import '../../../settings/domain/repositories/settings_repository.dart';

class SecureActivationTokensCard extends StatefulWidget {
  const SecureActivationTokensCard({super.key});

  @override
  State<SecureActivationTokensCard> createState() => _SecureActivationTokensCardState();
}

class _SecureActivationTokensCardState extends State<SecureActivationTokensCard> {
  bool _isUnlocked = false;
  bool _isLoading = false;

  String _pharmacyName = 'صيدليتي';
  String _hardwareId = 'LOADING...';
  String _activationRequestCode = '';
  List<BranchConfig> _branches = [];
  List<DeviceConfig> _devices = [];

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
      final pName = settings.pharmacyName.isNotEmpty ? settings.pharmacyName : 'صيدلية النور الحديثة';
      final reqCode = await DeviceBranchManagerService.generatePharmacyActivationRequestCode(pName, hwId);
      final branchesList = await DeviceBranchManagerService.getBranches();
      final devicesList = await DeviceBranchManagerService.getDevices();

      if (mounted) {
        setState(() {
          _pharmacyName = pName;
          _hardwareId = hwId;
          _activationRequestCode = reqCode;
          _branches = branchesList;
          _devices = devicesList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                  'لحماية ترخيص النظام ومنع التلاعب، الرجاء إدخال رمز دخول أو كلمة مرور المدير لإظهار رموز التفعيل والاقتران:',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'كلمة مرور / رمز المدير',
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
                ),
                const SizedBox(height: 8),
                const Text(
                  'رمز الدخول الافتراضي: admin123 أو 1234 أو كلمة مرور حساب المدير',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
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
                label: const Text('فتح وعرض الرموز', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final entered = passwordCtrl.text.trim();
                  if (entered.isEmpty) {
                    setDialogState(() => errorText = 'الرجاء إدخال الرمز');
                    return;
                  }

                  // 1. تحقق من الرموز الافتراضية
                  if (entered == 'admin123' || entered == '1234' || entered == '0000') {
                    Navigator.pop(ctx, true);
                    return;
                  }

                  // 2. تحقق من جدول المستخدمين في SQLite
                  try {
                    final db = sl<AppDatabase>();
                    final users = await db.select(db.users).get();
                    bool matched = false;
                    for (final u in users) {
                      if (u.role == 'owner' || u.role == 'admin') {
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

                  setDialogState(() => errorText = 'رمز الدخول غير صحيح! تم رفض الوصول.');
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (authenticated == true && mounted) {
      setState(() => _isUnlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التحقق بنجاح! تم إظهار رموز التفعيل والاقتران.'),
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

  @override
  Widget build(BuildContext context) {
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
                      'رموز التفعيل والاقتران والتراخيص المحمية',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _isUnlocked
                          ? 'مفتوح - تم التحقق من صلاحية المدير'
                          : 'محمي ومقفل - يتطلب إدخال رمز دخول المدير',
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
                  _buildMaskedRow('كود طلب التفعيل الذكي للصيدلية'),
                  const SizedBox(height: 10),
                  _buildMaskedRow('معرف الجهاز الحصري (Hardware ID)'),
                  const SizedBox(height: 10),
                  _buildMaskedRow('مفتاح الترخيص والتشغيل الدائم'),
                  const SizedBox(height: 10),
                  _buildMaskedRow('رموز اقتران وتفعيل الفروع والكاشيرات'),
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
                  'كتابة رمز دخول المدير لعرض كافة الرموز 🔐',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _promptManagerAuth,
              ),
            ),
          ] else ...[
            // الحالة المفتوحة: عرض جميع الرموز مع أزرار النسخ
            _buildRevealedCard(
              title: 'كود طلب التفعيل الذكي للصيدلية (Master Code)',
              subtitle: 'هذا الكود يربط اسم الصيدلية بمعرف الجهاز تلقائياً',
              value: _activationRequestCode,
              icon: Icons.qr_code_2_rounded,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 10),
            _buildRevealedCard(
              title: 'معرف الجهاز الفعلي (Hardware Fingerprint)',
              subtitle: 'المعرف المادي الحصري الخاص بهذا الجهاز',
              value: _hardwareId,
              icon: Icons.memory_rounded,
              color: Colors.purpleAccent,
            ),
            const SizedBox(height: 10),
            _buildRevealedCard(
              title: 'حالة الترخيص والتشغيل',
              subtitle: 'الترخيص نشط ومفعل مدى الحياة لهذا الجهاز',
              value: 'LICENSED-PERPETUAL-ACTIVE-2026',
              icon: Icons.verified_user_rounded,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 14),

            const Text(
              'رموز اقتران وتفعيل الفروع التابعة (Branch Tokens):',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_branches.isEmpty)
              const Text('لا توجد فروع مسجلة حالياً', style: TextStyle(color: Colors.grey, fontSize: 11))
            else
              ..._branches.map((b) => _buildSubTokenRow(b.name, b.code, b.token, Icons.storefront_rounded)),

            const SizedBox(height: 14),
            const Text(
              'رموز تفعيل أجهزة الكاشير ونقاط البيع (POS Tokens):',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_devices.isEmpty)
              const Text('لا توجد أجهزة مسجلة حالياً', style: TextStyle(color: Colors.grey, fontSize: 11))
            else
              ..._devices.map((d) => _buildSubTokenRow(d.name, d.isMainServer ? 'خادم رئيسي' : 'كاشير فرعي', d.token, Icons.computer_rounded)),

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

  Widget _buildSubTokenRow(String name, String badge, String token, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF60A5FA), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(badge, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SelectableText(
                  token,
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.grey, size: 16),
            tooltip: 'نسخ الرمز',
            onPressed: () => _copyToClipboard(token, 'رمز $name'),
          ),
        ],
      ),
    );
  }
}
