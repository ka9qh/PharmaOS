import '../entities/insurance_entities.dart';

abstract class InsuranceRepository {
  // ========== شركات التأمين ==========
  Future<List<InsuranceCompanyEntity>> getAllCompanies();
  Future<InsuranceCompanyEntity> createCompany({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? contactPerson,
    double defaultCoveragePercent = 0,
    double maxCoveragePerInvoice = 0,
    String? notes,
  });
  Future<void> updateCompany(int id, {
    String? name,
    String? phone,
    String? email,
    String? address,
    String? contactPerson,
    double? defaultCoveragePercent,
    double? maxCoveragePerInvoice,
    bool? isActive,
    String? notes,
  });

  // ========== بوالص التأمين ==========
  Future<List<InsurancePolicyEntity>> getAllPolicies();
  Future<List<InsurancePolicyEntity>> getPoliciesForCustomer(int customerId);
  Future<InsurancePolicyEntity?> getActivePolicy(int customerId);
  Future<InsurancePolicyEntity> createPolicy({
    required int customerId,
    required int insuranceCompanyId,
    required String policyNumber,
    required double coveragePercent,
    double monthlyLimit = 0,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
  });
  Future<void> updatePolicy(int id, {
    String? policyNumber,
    double? coveragePercent,
    double? monthlyLimit,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? notes,
  });

  /// تحديث المبلغ المستهلك من الحد الشهري بعد كل فاتورة تأمين
  Future<void> addMonthlyUsage(int policyId, double amount);
  
  /// تصفير المستهلك الشهري (يُنفذ بداية كل شهر)
  Future<void> resetMonthlyUsage();
}
