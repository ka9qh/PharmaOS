// خدمة ربط الموردين بالشركات ومحرك مطابقة مورد الدواء - PharmaOS
// تتيح تعيين الشركات والمنتجات التي يوزعها كل مورد، والبحث الفوري عن مورد أي علاج
// وتجهيز رسائل ورابط واتساب للطلب بلمسة واحدة.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SupplierDistributionProfile {
  final int supplierId;
  final String supplierName;
  final String? phone;
  final String? whatsappNumber;
  final List<String> representedCompanies; // أسماء أو معرّفات الشركات التي يوزع لها
  final List<String> distributedCategories; // التصنيفات أو خطوط الإنتاج
  final String? notes;

  SupplierDistributionProfile({
    required this.supplierId,
    required this.supplierName,
    this.phone,
    this.whatsappNumber,
    this.representedCompanies = const [],
    this.distributedCategories = const [],
    this.notes,
  });

  SupplierDistributionProfile copyWith({
    String? supplierName,
    String? phone,
    String? whatsappNumber,
    List<String>? representedCompanies,
    List<String>? distributedCategories,
    String? notes,
  }) {
    return SupplierDistributionProfile(
      supplierId: supplierId,
      supplierName: supplierName ?? this.supplierName,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      representedCompanies: representedCompanies ?? this.representedCompanies,
      distributedCategories: distributedCategories ?? this.distributedCategories,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'supplierId': supplierId,
        'supplierName': supplierName,
        'phone': phone,
        'whatsappNumber': whatsappNumber,
        'representedCompanies': representedCompanies,
        'distributedCategories': distributedCategories,
        'notes': notes,
      };

  factory SupplierDistributionProfile.fromJson(Map<String, dynamic> json) => SupplierDistributionProfile(
        supplierId: json['supplierId'] as int,
        supplierName: json['supplierName'] as String,
        phone: json['phone'] as String?,
        whatsappNumber: json['whatsappNumber'] as String?,
        representedCompanies: (json['representedCompanies'] as List?)?.map((e) => e.toString()).toList() ?? [],
        distributedCategories: (json['distributedCategories'] as List?)?.map((e) => e.toString()).toList() ?? [],
        notes: json['notes'] as String?,
      );
}

class SupplierCatalogMappingService {
  static const String _profilesKey = 'supplier_distribution_profiles_v1';

  static Future<Map<int, SupplierDistributionProfile>> getAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      final map = <int, SupplierDistributionProfile>{};
      decoded.forEach((key, val) {
        final id = int.tryParse(key);
        if (id != null) {
          map[id] = SupplierDistributionProfile.fromJson(val);
        }
      });
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveProfile(SupplierDistributionProfile profile) async {
    final profiles = await getAllProfiles();
    profiles[profile.supplierId] = profile;
    final prefs = await SharedPreferences.getInstance();
    final mapToSave = profiles.map((k, v) => MapEntry(k.toString(), v.toJson()));
    await prefs.setString(_profilesKey, jsonEncode(mapToSave));
  }

  static Future<SupplierDistributionProfile?> getProfile(int supplierId) async {
    final profiles = await getAllProfiles();
    return profiles[supplierId];
  }

  // إنشاء رابط واتساب فوري لطلب الدواء
  static Future<void> launchWhatsAppOrder({
    required String? rawPhone,
    required String medicineName,
    String? companyName,
    String pharmacyName = 'الصيدلية',
  }) async {
    if (rawPhone == null || rawPhone.trim().isEmpty) return;

    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!cleanPhone.startsWith('+') && !cleanPhone.startsWith('00') && !cleanPhone.startsWith('967')) {
      if (cleanPhone.startsWith('7') || cleanPhone.startsWith('07')) {
        cleanPhone = '967${cleanPhone.replaceFirst(RegExp(r'^0'), '')}';
      }
    }

    final message = Uri.encodeComponent(
      'مرحباً، نحتاج طلبية عاجلة من صيدلية $pharmacyName:\n'
      '🔹 الدواء المطلوب: $medicineName\n'
      '${companyName != null && companyName.isNotEmpty ? "🔹 الشركة المصنعة: $companyName\n" : ""}'
      'يرجى إفادتنا بتوفر الصنف والكمية والأسعار الحالية. شكراً لكم.',
    );

    final urlString = 'https://wa.me/$cleanPhone?text=$message';
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // إجراء مكالمة هاتفية مباشرة
  static Future<void> launchPhoneCall(String? rawPhone) async {
    if (rawPhone == null || rawPhone.trim().isEmpty) return;
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
