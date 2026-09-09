// توليد معرف فريد وثابت للجهاز (Hardware Fingerprint) - Windows فقط
//
// الطريقة: يحاول عدة مصادر بالترتيب (لأن wmic أصبح مهجورًا في إصدارات ويندوز
// الحديثة لصالح PowerShell، لكنه لا يزال متوفرًا في أغلب الأجهزة الحالية):
// 1) wmic csproduct get uuid (الأكثر شيوعًا وثباتًا عبر إعادة التشغيل)
// 2) PowerShell: Get-CimInstance Win32_ComputerSystemProduct (بديل حديث)
// 3) قراءة MachineGuid من سجل النظام (احتياطي أخير)
//
// ⚠️ ملاحظة صادقة مهمة: لم أتمكن من اختبار هذا الملف على جهاز Windows فعلي
// من هذه المحادثة (لا تتوفر بيئة Windows هنا). إذا فشلت كل الطرق الثلاث على
// جهازك، أخبرني بالضبط بأي خطأ ظهر وسأعدّل الأسلوب بدقة.

import 'dart:io';

class HardwareIdGenerator {
  HardwareIdGenerator._();

  static String? _cachedId;

  /// يُرجع معرف الجهاز، ويخزّنه مؤقتًا في الذاكرة لتفادي استدعاء العمليات
  /// الخارجية أكثر من مرة في نفس جلسة التشغيل.
  static Future<String> getHardwareId() async {
    if (_cachedId != null) return _cachedId!;

    final id = await _tryWmic() ?? await _tryPowerShell() ?? await _tryRegistry() ?? _fallbackId();

    _cachedId = id;
    return id;
  }

  static Future<String?> _tryWmic() async {
    try {
      final result = await Process.run('wmic', ['csproduct', 'get', 'uuid']);
      if (result.exitCode != 0) return null;
      final lines = (result.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l.toUpperCase() != 'UUID')
          .toList();
      if (lines.isEmpty) return null;
      return 'WMIC-${lines.first}';
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _tryPowerShell() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystemProduct).UUID',
      ]);
      if (result.exitCode != 0) return null;
      final value = (result.stdout as String).trim();
      if (value.isEmpty) return null;
      return 'PS-$value';
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _tryRegistry() async {
    try {
      final result = await Process.run('reg', [
        'query',
        r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography',
        '/v',
        'MachineGuid',
      ]);
      if (result.exitCode != 0) return null;
      final output = result.stdout as String;
      final match = RegExp(r'MachineGuid\s+REG_SZ\s+(\S+)').firstMatch(output);
      if (match == null) return null;
      return 'REG-${match.group(1)}';
    } catch (_) {
      return null;
    }
  }

  /// احتياطي أخير إذا فشلت كل الطرق أعلاه (نادر جدًا) - يعتمد على اسم الجهاز
  /// فقط، وهو أقل دقة (يمكن أن يتشابه بين جهازين بنفس الاسم)، لذا يُستخدم
  /// فقط كملاذ أخير حتى لا يتوقف التطبيق عن العمل نهائيًا.
  static String _fallbackId() {
    final hostname = Platform.localHostname;
    return 'HOST-$hostname';
  }
}
