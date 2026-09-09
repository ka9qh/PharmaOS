class InsuranceCompanyEntity {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? contactPerson;
  final double defaultCoveragePercent;
  final double maxCoveragePerInvoice;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;

  InsuranceCompanyEntity({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.contactPerson,
    required this.defaultCoveragePercent,
    required this.maxCoveragePerInvoice,
    required this.isActive,
    this.notes,
    required this.createdAt,
  });
}

class InsurancePolicyEntity {
  final int id;
  final int customerId;
  final String customerName;
  final int insuranceCompanyId;
  final String insuranceCompanyName;
  final String policyNumber;
  final double coveragePercent;
  final double monthlyLimit;
  final double monthlyUsed;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;

  InsurancePolicyEntity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.insuranceCompanyId,
    required this.insuranceCompanyName,
    required this.policyNumber,
    required this.coveragePercent,
    required this.monthlyLimit,
    required this.monthlyUsed,
    required this.startDate,
    this.endDate,
    required this.isActive,
    this.notes,
    required this.createdAt,
  });

  /// حساب المبلغ المتبقي من الحد الشهري
  double get remainingMonthlyLimit => monthlyLimit > 0 ? (monthlyLimit - monthlyUsed) : double.infinity;

  /// هل البوليصة سارية الآن؟
  bool get isValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (now.isBefore(startDate)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  /// حساب التغطية الفعلية لمبلغ معين
  double calculateCoverage(double invoiceTotal) {
    final rawCoverage = invoiceTotal * (coveragePercent / 100);
    // التقيد بالحد الأقصى الشهري المتبقي
    if (monthlyLimit > 0) {
      final remaining = monthlyLimit - monthlyUsed;
      return rawCoverage > remaining ? remaining : rawCoverage;
    }
    return rawCoverage;
  }
}
