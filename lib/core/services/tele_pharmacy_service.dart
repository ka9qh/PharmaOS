// خدمة الاستشارات والروشتات الطبية الفورية (Tele-Pharmacy Service) - PharmaOS
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'cloud_sync_service.dart';
import 'license_service.dart';

class TeleConsultation {
  final int id;
  final int pharmacyId;
  final int? branchId;
  final String pharmacistName;
  final String title;
  final String? patientName;
  final String? notes;
  final String? imageBase64;
  final String? imageUrl;
  final String? voiceBase64;
  final String status; // pending, answered, resolved, cancelled
  final String urgency; // normal, urgent, critical
  final String? suggestedMedicines;
  final String? managerReply;
  final String? managerName;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? resolvedAt;

  TeleConsultation({
    required this.id,
    required this.pharmacyId,
    this.branchId,
    required this.pharmacistName,
    required this.title,
    this.patientName,
    this.notes,
    this.imageBase64,
    this.imageUrl,
    this.voiceBase64,
    required this.status,
    required this.urgency,
    this.suggestedMedicines,
    this.managerReply,
    this.managerName,
    required this.createdAt,
    this.answeredAt,
    this.resolvedAt,
  });

  factory TeleConsultation.fromJson(Map<String, dynamic> json) {
    return TeleConsultation(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id'].toString()) ?? 1,
      branchId: json['branch_id'] != null ? int.tryParse(json['branch_id'].toString()) : null,
      pharmacistName: json['pharmacist_name'] ?? 'الصيدلي',
      title: json['title'] ?? 'استشارة طبية',
      patientName: json['patient_name'],
      notes: json['notes'],
      imageBase64: json['image_base64'],
      imageUrl: json['image_url'],
      voiceBase64: json['voice_base64'],
      status: json['status'] ?? 'pending',
      urgency: json['urgency'] ?? 'normal',
      suggestedMedicines: json['suggested_medicines'],
      managerReply: json['manager_reply'],
      managerName: json['manager_name'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
      answeredAt: json['answered_at'] != null ? DateTime.tryParse(json['answered_at']) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'pharmacy_id': pharmacyId,
        'branch_id': branchId,
        'pharmacist_name': pharmacistName,
        'title': title,
        'patient_name': patientName,
        'notes': notes,
        'image_base64': imageBase64,
        'image_url': imageUrl,
        'voice_base64': voiceBase64,
        'status': status,
        'urgency': urgency,
        'suggested_medicines': suggestedMedicines,
        'manager_reply': managerReply,
        'manager_name': managerName,
        'created_at': createdAt.toIso8601String(),
        'answered_at': answeredAt?.toIso8601String(),
        'resolved_at': resolvedAt?.toIso8601String(),
      };
}

class TelePharmacyService {
  static Map<String, String> _getHeaders(String apiKey) {
    return {
      'apikey': apiKey,
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
  }

  /// إرسال استشارة أو روشتة جديدة من الصيدلي للمدير
  static Future<TeleConsultation?> sendConsultation({
    required String title,
    String? patientName,
    String? notes,
    String? imageBase64,
    String? voiceBase64,
    String urgency = 'normal',
    String pharmacistName = 'الصيدلي المناوب',
  }) async {
    try {
      final tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();
      final pharmacyId = int.tryParse(tenantConfig.pharmacyId) ?? 1;
      final branchId = int.tryParse(tenantConfig.branchId) ?? 1;

      final payload = {
        'pharmacy_id': pharmacyId,
        'branch_id': branchId,
        'pharmacist_name': pharmacistName,
        'title': title,
        'patient_name': patientName,
        'notes': notes,
        'image_base64': imageBase64,
        'voice_base64': voiceBase64,
        'status': 'pending',
        'urgency': urgency,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await http
          .post(
            Uri.parse('$supabaseUrl/rest/v1/cloud_tele_consultations'),
            headers: _getHeaders(apiKey),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return TeleConsultation.fromJson(data.first);
        }
      } else {
        debugPrint('TelePharmacy send error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('TelePharmacyService sendConsultation error: $e');
    }
    return null;
  }

  /// جلب قائمة الاستشارات المعزولة الخاصة بالصيدلية الحالية
  static Future<List<TeleConsultation>> fetchConsultations({
    int? customPharmacyId,
    String? status,
    int limit = 50,
  }) async {
    try {
      final tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();
      final pharmacyId = customPharmacyId ?? (int.tryParse(tenantConfig.pharmacyId) ?? 1);

      String query = '$supabaseUrl/rest/v1/cloud_tele_consultations?pharmacy_id=eq.$pharmacyId';
      if (status != null && status.isNotEmpty) {
        query += '&status=eq.$status';
      }
      query += '&order=created_at.desc&limit=$limit';

      final response = await http
          .get(
            Uri.parse(query),
            headers: _getHeaders(apiKey),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((json) => TeleConsultation.fromJson(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('TelePharmacyService fetchConsultations error: $e');
    }
    return [];
  }

  /// رد المدير على استشارة أو روشتة محددة
  static Future<bool> replyToConsultation({
    required int consultationId,
    required String reply,
    String? suggestedMedicines,
    String? voiceBase64,
    String managerName = 'المدير العام',
    String newStatus = 'answered',
  }) async {
    try {
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();

      final payload = {
        'manager_reply': reply,
        'suggested_medicines': suggestedMedicines,
        if (voiceBase64 != null) 'voice_base64': voiceBase64,
        'manager_name': managerName,
        'status': newStatus,
        'answered_at': DateTime.now().toIso8601String(),
      };

      final response = await http
          .patch(
            Uri.parse('$supabaseUrl/rest/v1/cloud_tele_consultations?id=eq.$consultationId'),
            headers: _getHeaders(apiKey),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('TelePharmacyService replyToConsultation error: $e');
      return false;
    }
  }

  /// إنهاء وإغلاق الاستشارة بعد صرف العلاج
  static Future<bool> markAsResolved(int consultationId) async {
    try {
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();

      final payload = {
        'status': 'resolved',
        'resolved_at': DateTime.now().toIso8601String(),
      };

      final response = await http
          .patch(
            Uri.parse('$supabaseUrl/rest/v1/cloud_tele_consultations?id=eq.$consultationId'),
            headers: _getHeaders(apiKey),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('TelePharmacyService markAsResolved error: $e');
      return false;
    }
  }
}
