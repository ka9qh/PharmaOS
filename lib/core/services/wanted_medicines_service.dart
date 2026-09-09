// خدمة إدارة النواقص وطلبات العملاء المتكررة وتنبيهات الطلب - PharmaOS
// تسجل طلبات الأدوية غير المتوفرة، وتحسب عداد مرات الطلب، وتربط بالطلب عبر واتساب

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WantedMedicineItem {
  final String id;
  final String medicineName;
  final int? medicineId;
  final String? companyName;
  final String? supplierName;
  final String? supplierPhone;
  final int demandCount; // كم مرة طلبه العملاء
  final String status; // 'pending', 'ordered', 'fulfilled'
  final List<String> requestingCustomerNames;
  final List<String> requestingCustomerPhones;
  final DateTime createdAt;
  final DateTime lastRequestedAt;
  final String? notes;

  WantedMedicineItem({
    required this.id,
    required this.medicineName,
    this.medicineId,
    this.companyName,
    this.supplierName,
    this.supplierPhone,
    this.demandCount = 1,
    this.status = 'pending',
    this.requestingCustomerNames = const [],
    this.requestingCustomerPhones = const [],
    required this.createdAt,
    required this.lastRequestedAt,
    this.notes,
  });

  WantedMedicineItem copyWith({
    String? medicineName,
    int? medicineId,
    String? companyName,
    String? supplierName,
    String? supplierPhone,
    int? demandCount,
    String? status,
    List<String>? requestingCustomerNames,
    List<String>? requestingCustomerPhones,
    DateTime? lastRequestedAt,
    String? notes,
  }) {
    return WantedMedicineItem(
      id: id,
      medicineName: medicineName ?? this.medicineName,
      medicineId: medicineId ?? this.medicineId,
      companyName: companyName ?? this.companyName,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      demandCount: demandCount ?? this.demandCount,
      status: status ?? this.status,
      requestingCustomerNames: requestingCustomerNames ?? this.requestingCustomerNames,
      requestingCustomerPhones: requestingCustomerPhones ?? this.requestingCustomerPhones,
      createdAt: createdAt,
      lastRequestedAt: lastRequestedAt ?? this.lastRequestedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineName': medicineName,
        'medicineId': medicineId,
        'companyName': companyName,
        'supplierName': supplierName,
        'supplierPhone': supplierPhone,
        'demandCount': demandCount,
        'status': status,
        'requestingCustomerNames': requestingCustomerNames,
        'requestingCustomerPhones': requestingCustomerPhones,
        'createdAt': createdAt.toIso8601String(),
        'lastRequestedAt': lastRequestedAt.toIso8601String(),
        'notes': notes,
      };

  factory WantedMedicineItem.fromJson(Map<String, dynamic> json) => WantedMedicineItem(
        id: json['id'] ?? '',
        medicineName: json['medicineName'] ?? '',
        medicineId: json['medicineId'] as int?,
        companyName: json['companyName'] as String?,
        supplierName: json['supplierName'] as String?,
        supplierPhone: json['supplierPhone'] as String?,
        demandCount: (json['demandCount'] as num?)?.toInt() ?? 1,
        status: json['status'] ?? 'pending',
        requestingCustomerNames: (json['requestingCustomerNames'] as List?)?.map((e) => e.toString()).toList() ?? [],
        requestingCustomerPhones: (json['requestingCustomerPhones'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        lastRequestedAt: DateTime.tryParse(json['lastRequestedAt'] ?? '') ?? DateTime.now(),
        notes: json['notes'] as String?,
      );
}

class WantedMedicinesService {
  static const String _wantedKey = 'wanted_medicines_v1';

  static Future<List<WantedMedicineItem>> getWantedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_wantedKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => WantedMedicineItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveWantedItems(List<WantedMedicineItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_wantedKey, encoded);
  }

  // إضافة أو زيادة عداد الطلب لدواء
  static Future<WantedMedicineItem> recordDemand({
    required String medicineName,
    int? medicineId,
    String? companyName,
    String? supplierName,
    String? supplierPhone,
    String? customerName,
    String? customerPhone,
    String? notes,
  }) async {
    final list = await getWantedItems();
    final cleanName = medicineName.trim().toLowerCase();

    final existingIndex = list.indexWhere(
      (item) => item.medicineName.trim().toLowerCase() == cleanName && item.status != 'fulfilled',
    );

    if (existingIndex != -1) {
      final existing = list[existingIndex];
      final names = List<String>.from(existing.requestingCustomerNames);
      final phones = List<String>.from(existing.requestingCustomerPhones);

      if (customerName != null && customerName.isNotEmpty && !names.contains(customerName)) {
        names.add(customerName);
      }
      if (customerPhone != null && customerPhone.isNotEmpty && !phones.contains(customerPhone)) {
        phones.add(customerPhone);
      }

      final updated = existing.copyWith(
        demandCount: existing.demandCount + 1,
        requestingCustomerNames: names,
        requestingCustomerPhones: phones,
        lastRequestedAt: DateTime.now(),
        companyName: companyName ?? existing.companyName,
        supplierName: supplierName ?? existing.supplierName,
        supplierPhone: supplierPhone ?? existing.supplierPhone,
      );

      list[existingIndex] = updated;
      await saveWantedItems(list);
      return updated;
    } else {
      final newItem = WantedMedicineItem(
        id: 'WANT-${DateTime.now().millisecondsSinceEpoch}',
        medicineName: medicineName.trim(),
        medicineId: medicineId,
        companyName: companyName,
        supplierName: supplierName,
        supplierPhone: supplierPhone,
        demandCount: 1,
        status: 'pending',
        requestingCustomerNames: customerName != null && customerName.isNotEmpty ? [customerName] : [],
        requestingCustomerPhones: customerPhone != null && customerPhone.isNotEmpty ? [customerPhone] : [],
        createdAt: DateTime.now(),
        lastRequestedAt: DateTime.now(),
        notes: notes,
      );

      list.insert(0, newItem);
      await saveWantedItems(list);
      return newItem;
    }
  }

  static Future<void> updateStatus(String id, String status) async {
    final list = await getWantedItems();
    final index = list.indexWhere((i) => i.id == id);
    if (index != -1) {
      list[index] = list[index].copyWith(status: status);
      await saveWantedItems(list);
    }
  }

  static Future<void> deleteItem(String id) async {
    final list = await getWantedItems();
    list.removeWhere((i) => i.id == id);
    await saveWantedItems(list);
  }

  static Future<int> getHighDemandPendingCount() async {
    final list = await getWantedItems();
    return list.where((i) => i.status == 'pending' && i.demandCount >= 2).length;
  }
}
