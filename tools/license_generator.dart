// أداة توليد مفاتيح التراخيص - PharmaOS
//
// ⚠️ للاستخدام الداخلي فقط على جهازك أنت (كمزوّد النظام). هذا الملف خارج
// مجلد lib/ تمامًا، لذلك flutter build windows لا يُدرجه إطلاقًا ضمن الملف
// التنفيذي المُوزَّع للصيدليات - آمن بشكل طبيعي دون أي إعداد إضافي.
//
// طريقة الاستخدام:
//   dart run tools/license_generator.dart <hardware_id> "<اسم الصيدلية>" [عدد الأيام]
//
// مثال (ترخيص دائم بدون تاريخ انتهاء):
//   dart run tools/license_generator.dart "WMIC-1234-5678" "صيدلية النور"
//
// مثال (ترخيص صالح لمدة سنة - 365 يومًا):
//   dart run tools/license_generator.dart "WMIC-1234-5678" "صيدلية النور" 365
//
// من أين تحصل على hardware_id؟ صاحب الصيدلية يرسله لك من شاشة التفعيل
// (تظهر تلقائيًا عند أول تشغيل للنظام مع زر نسخ).

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:pharmaos/core/licensing/license_secret.dart';

String _sign(String payloadBase64) {
  final hmac = Hmac(sha256, utf8.encode(LicenseSecret.value));
  return hmac.convert(utf8.encode(payloadBase64)).toString();
}

void main(List<String> args) {
  if (args.length < 2) {
    print('الاستخدام:');
    print('  dart run tools/license_generator.dart <hardware_id> "<اسم الصيدلية>" [عدد الأيام]');
    return;
  }

  final hardwareId = args[0];
  final pharmacyName = args[1];
  final daysValid = args.length >= 3 ? int.tryParse(args[2]) : null;

  final issuedAt = DateTime.now();
  final expiresAt = daysValid != null ? issuedAt.add(Duration(days: daysValid)) : null;

  final payload = {
    'hwid': hardwareId,
    'pharmacy': pharmacyName,
    'issued': issuedAt.toIso8601String(),
    'expires': expiresAt?.toIso8601String(),
  };

  final payloadJson = jsonEncode(payload);
  final payloadBase64 = base64Url.encode(utf8.encode(payloadJson));
  final signature = _sign(payloadBase64);
  final licenseKey = '$payloadBase64.$signature';

  print('');
  print('=== مفتاح الترخيص (انسخه بالكامل وأرسله لصاحب الصيدلية) ===');
  print(licenseKey);
  print('');
  print('الصيدلية: $pharmacyName');
  print('معرف الجهاز: $hardwareId');
  print('تاريخ الإصدار: ${issuedAt.toIso8601String()}');
  print('تاريخ الانتهاء: ${expiresAt?.toIso8601String() ?? "دائم (بدون انتهاء)"}');
  print('');
}
