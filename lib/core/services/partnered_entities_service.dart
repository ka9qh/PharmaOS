// خدمة إدارة الموردين والشركات المتعامل معهم - PharmaOS
// تضمن أن تبدأ القوائم فارغة، ويتولى الصيدلي تفعيل وإضافة من يتعامل معهم فقط.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PartneredEntitiesService {
  static const String _partneredSuppliersKey = 'partnered_suppliers_ids_v1';
  static const String _partneredCompaniesKey = 'partnered_companies_ids_v1';
  static const String _externalDebtsKey = 'pharmacy_external_debts_v1';

  // ---------------- الموردون المتعامل معهم ----------------
  static Future<List<int>> getPartneredSupplierIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_partneredSuppliersKey);
    if (list == null) return [];
    return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();
  }

  static Future<void> addPartneredSupplier(int supplierId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getPartneredSupplierIds();
    if (!current.contains(supplierId)) {
      current.add(supplierId);
      await prefs.setStringList(_partneredSuppliersKey, current.map((e) => e.toString()).toList());
    }
  }

  static Future<void> removePartneredSupplier(int supplierId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getPartneredSupplierIds();
    current.remove(supplierId);
    await prefs.setStringList(_partneredSuppliersKey, current.map((e) => e.toString()).toList());
  }

  // ---------------- الشركات المتعامل معها ----------------
  static Future<List<int>> getPartneredCompanyIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_partneredCompaniesKey);
    if (list == null) return [];
    return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();
  }

  static Future<void> addPartneredCompany(int companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getPartneredCompanyIds();
    if (!current.contains(companyId)) {
      current.add(companyId);
      await prefs.setStringList(_partneredCompaniesKey, current.map((e) => e.toString()).toList());
    }
  }

  static Future<void> removePartneredCompany(int companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getPartneredCompanyIds();
    current.remove(companyId);
    await prefs.setStringList(_partneredCompaniesKey, current.map((e) => e.toString()).toList());
  }

  // ---------------- الديون الخارجية العامة للصيدلية ----------------
  static Future<List<ExternalDebtItem>> getExternalDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_externalDebtsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((item) => ExternalDebtItem.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveExternalDebts(List<ExternalDebtItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_externalDebtsKey, encoded);
  }

  static Future<void> addExternalDebt(ExternalDebtItem item) async {
    final current = await getExternalDebts();
    current.insert(0, item);
    await saveExternalDebts(current);
  }

  static Future<void> recordPaymentForExternalDebt(String debtId, double amount, String method, String? notes) async {
    final current = await getExternalDebts();
    final index = current.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      final old = current[index];
      final newPaid = old.paidAmount + amount;
      final updated = old.copyWith(
        paidAmount: newPaid,
        payments: [
          ...old.payments,
          DebtPaymentRecord(
            amount: amount,
            date: DateTime.now(),
            method: method,
            notes: notes,
          ),
        ],
      );
      current[index] = updated;
      await saveExternalDebts(current);
    }
  }
}

class DebtPaymentRecord {
  final double amount;
  final DateTime date;
  final String method;
  final String? notes;

  DebtPaymentRecord({
    required this.amount,
    required this.date,
    required this.method,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'date': date.toIso8601String(),
        'method': method,
        'notes': notes,
      };

  factory DebtPaymentRecord.fromJson(Map<String, dynamic> json) => DebtPaymentRecord(
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        method: json['method'] ?? 'نقدي',
        notes: json['notes'],
      );
}

class ExternalDebtItem {
  final String id;
  final String creditorName; // اسم الجهة الدائنة (مؤجر، شركة كهرباء، بنك، مهندس صيانة...)
  final String reason; // سبب الدين / البيان
  final double totalAmount; // المبلغ الإجمالي
  final double paidAmount; // المبلغ المسدد
  final DateTime date; // تاريخ نشوء الدين
  final String? notes; // ملاحظات أو شروط
  final List<DebtPaymentRecord> payments;

  double get remainingDebt => (totalAmount - paidAmount) > 0 ? (totalAmount - paidAmount) : 0.0;

  ExternalDebtItem({
    required this.id,
    required this.creditorName,
    required this.reason,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.date,
    this.notes,
    this.payments = const [],
  });

  ExternalDebtItem copyWith({
    String? id,
    String? creditorName,
    String? reason,
    double? totalAmount,
    double? paidAmount,
    DateTime? date,
    String? notes,
    List<DebtPaymentRecord>? payments,
  }) {
    return ExternalDebtItem(
      id: id ?? this.id,
      creditorName: creditorName ?? this.creditorName,
      reason: reason ?? this.reason,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      payments: payments ?? this.payments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creditorName': creditorName,
        'reason': reason,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'date': date.toIso8601String(),
        'notes': notes,
        'payments': payments.map((p) => p.toJson()).toList(),
      };

  factory ExternalDebtItem.fromJson(Map<String, dynamic> json) => ExternalDebtItem(
        id: json['id'],
        creditorName: json['creditorName'],
        reason: json['reason'],
        totalAmount: (json['totalAmount'] as num).toDouble(),
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.parse(json['date']),
        notes: json['notes'],
        payments: (json['payments'] as List?)?.map((p) => DebtPaymentRecord.fromJson(p)).toList() ?? [],
      );
}
