// التحقق من صلاحية مفتاح ترخيص أوفلاين بالكامل (بدون أي اتصال إنترنت)
//
// صيغة المفتاح: {payload_base64}.{hmac_sha256_hex}
// الـ payload هو JSON يحتوي: hwid, pharmacy, issued, expires (اختياري)
// راجع tools/license_generator.dart لأداة توليد المفاتيح (تعمل بنفس هذا المنطق تمامًا).

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'license_secret.dart';

class LicensePayload {
  final String hardwareId;
  final String pharmacyName;
  final DateTime issuedAt;
  final DateTime? expiresAt; // null = ترخيص دائم

  const LicensePayload({
    required this.hardwareId,
    required this.pharmacyName,
    required this.issuedAt,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'hwid': hardwareId,
        'pharmacy': pharmacyName,
        'issued': issuedAt.toIso8601String(),
        'expires': expiresAt?.toIso8601String(),
      };

  factory LicensePayload.fromJson(Map<String, dynamic> json) => LicensePayload(
        hardwareId: json['hwid'] as String,
        pharmacyName: json['pharmacy'] as String,
        issuedAt: DateTime.parse(json['issued'] as String),
        expiresAt: json['expires'] != null ? DateTime.parse(json['expires'] as String) : null,
      );

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

enum LicenseCheckResult {
  valid,
  invalidSignature,
  malformed,
  hardwareMismatch,
  expired,
}

class LicenseValidationOutcome {
  final LicenseCheckResult result;
  final LicensePayload? payload;

  const LicenseValidationOutcome(this.result, this.payload);

  bool get isValid => result == LicenseCheckResult.valid;
}

class LicenseValidator {
  LicenseValidator._();

  static String _sign(String payloadBase64) {
    final hmac = Hmac(sha256, utf8.encode(LicenseSecret.value));
    return hmac.convert(utf8.encode(payloadBase64)).toString();
  }

  /// مقارنة نصوص بزمن ثابت (Constant-Time) لتفادي هجمات قياس التوقيت النظرية
  /// على مقارنة التوقيع - احتياط إضافي غير مكلف.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static LicenseValidationOutcome validate(String licenseKey, {required String currentHardwareId}) {
    final parts = licenseKey.trim().split('.');
    if (parts.length != 2) {
      return const LicenseValidationOutcome(LicenseCheckResult.malformed, null);
    }

    final payloadBase64 = parts[0];
    final providedSignature = parts[1];
    final expectedSignature = _sign(payloadBase64);

    if (!_constantTimeEquals(providedSignature, expectedSignature)) {
      return const LicenseValidationOutcome(LicenseCheckResult.invalidSignature, null);
    }

    late LicensePayload payload;
    try {
      final jsonStr = utf8.decode(base64Url.decode(base64Url.normalize(payloadBase64)));
      payload = LicensePayload.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return const LicenseValidationOutcome(LicenseCheckResult.malformed, null);
    }

    if (payload.hardwareId != currentHardwareId) {
      return LicenseValidationOutcome(LicenseCheckResult.hardwareMismatch, payload);
    }

    if (payload.isExpired) {
      return LicenseValidationOutcome(LicenseCheckResult.expired, payload);
    }

    return LicenseValidationOutcome(LicenseCheckResult.valid, payload);
  }
}
