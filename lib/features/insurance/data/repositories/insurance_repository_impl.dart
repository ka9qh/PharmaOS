import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/audit_logger.dart';
import '../../domain/entities/insurance_entities.dart';
import '../../domain/repositories/insurance_repository.dart';

class InsuranceRepositoryImpl implements InsuranceRepository {
  final AppDatabase _db;
  final AuditLogger _auditLogger;

  InsuranceRepositoryImpl(this._db, this._auditLogger);

  // ========== شركات التأمين ==========
  @override
  Future<List<InsuranceCompanyEntity>> getAllCompanies() async {
    final rows = await _db.select(_db.insuranceCompanies).get();
    return rows.map((r) => InsuranceCompanyEntity(
      id: r.id,
      name: r.name,
      phone: r.phone,
      email: r.email,
      address: r.address,
      contactPerson: r.contactPerson,
      defaultCoveragePercent: r.defaultCoveragePercent,
      maxCoveragePerInvoice: r.maxCoveragePerInvoice,
      isActive: r.isActive,
      notes: r.notes,
      createdAt: r.createdAt,
    )).toList();
  }

  @override
  Future<InsuranceCompanyEntity> createCompany({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? contactPerson,
    double defaultCoveragePercent = 0,
    double maxCoveragePerInvoice = 0,
    String? notes,
  }) async {
    final id = await _db.into(_db.insuranceCompanies).insert(
      InsuranceCompaniesCompanion.insert(
        name: name,
        phone: Value(phone),
        email: Value(email),
        address: Value(address),
        contactPerson: Value(contactPerson),
        defaultCoveragePercent: Value(defaultCoveragePercent),
        maxCoveragePerInvoice: Value(maxCoveragePerInvoice),
        notes: Value(notes),
      ),
    );
    await _auditLogger.log(
      actionType: 'INSURANCE_COMPANY_CREATED',
      tableName: 'insurance_companies',
      recordId: id.toString(),
      newValue: name,
    );
    return (await getAllCompanies()).firstWhere((c) => c.id == id);
  }

  @override
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
  }) async {
    await (_db.update(_db.insuranceCompanies)..where((c) => c.id.equals(id))).write(
      InsuranceCompaniesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        email: email != null ? Value(email) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        contactPerson: contactPerson != null ? Value(contactPerson) : const Value.absent(),
        defaultCoveragePercent: defaultCoveragePercent != null ? Value(defaultCoveragePercent) : const Value.absent(),
        maxCoveragePerInvoice: maxCoveragePerInvoice != null ? Value(maxCoveragePerInvoice) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
      ),
    );
    await _auditLogger.log(
      actionType: 'INSURANCE_COMPANY_UPDATED',
      tableName: 'insurance_companies',
      recordId: id.toString(),
    );
  }

  // ========== بوالص التأمين ==========
  Future<InsurancePolicyEntity> _mapPolicyRow(InsurancePolicyRow r) async {
    final customer = await (_db.select(_db.customers)..where((c) => c.id.equals(r.customerId))).getSingle();
    final company = await (_db.select(_db.insuranceCompanies)..where((c) => c.id.equals(r.insuranceCompanyId))).getSingle();
    return InsurancePolicyEntity(
      id: r.id,
      customerId: r.customerId,
      customerName: customer.name,
      insuranceCompanyId: r.insuranceCompanyId,
      insuranceCompanyName: company.name,
      policyNumber: r.policyNumber,
      coveragePercent: r.coveragePercent,
      monthlyLimit: r.monthlyLimit,
      monthlyUsed: r.monthlyUsed,
      startDate: r.startDate,
      endDate: r.endDate,
      isActive: r.isActive,
      notes: r.notes,
      createdAt: r.createdAt,
    );
  }

  @override
  Future<List<InsurancePolicyEntity>> getAllPolicies() async {
    final rows = await _db.select(_db.insurancePolicies).get();
    return Future.wait(rows.map(_mapPolicyRow));
  }

  @override
  Future<List<InsurancePolicyEntity>> getPoliciesForCustomer(int customerId) async {
    final rows = await (_db.select(_db.insurancePolicies)
          ..where((p) => p.customerId.equals(customerId)))
        .get();
    return Future.wait(rows.map(_mapPolicyRow));
  }

  @override
  Future<InsurancePolicyEntity?> getActivePolicy(int customerId) async {
    final now = DateTime.now();
    final rows = await (_db.select(_db.insurancePolicies)
          ..where((p) =>
              p.customerId.equals(customerId) &
              p.isActive.equals(true) &
              p.startDate.isSmallerOrEqualValue(now)))
        .get();
    // تصفية البوالص المنتهية يدوياً (endDate nullable)
    final valid = rows.where((r) => r.endDate == null || r.endDate!.isAfter(now)).toList();
    if (valid.isEmpty) return null;
    return _mapPolicyRow(valid.first);
  }

  @override
  Future<InsurancePolicyEntity> createPolicy({
    required int customerId,
    required int insuranceCompanyId,
    required String policyNumber,
    required double coveragePercent,
    double monthlyLimit = 0,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
  }) async {
    final id = await _db.into(_db.insurancePolicies).insert(
      InsurancePoliciesCompanion.insert(
        customerId: customerId,
        insuranceCompanyId: insuranceCompanyId,
        policyNumber: policyNumber,
        coveragePercent: Value(coveragePercent),
        monthlyLimit: Value(monthlyLimit),
        startDate: startDate,
        endDate: Value(endDate),
        notes: Value(notes),
      ),
    );
    await _auditLogger.log(
      actionType: 'INSURANCE_POLICY_CREATED',
      tableName: 'insurance_policies',
      recordId: id.toString(),
      newValue: 'policy=$policyNumber, customer=$customerId',
    );
    return (await getAllPolicies()).firstWhere((p) => p.id == id);
  }

  @override
  Future<void> updatePolicy(int id, {
    String? policyNumber,
    double? coveragePercent,
    double? monthlyLimit,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? notes,
  }) async {
    await (_db.update(_db.insurancePolicies)..where((p) => p.id.equals(id))).write(
      InsurancePoliciesCompanion(
        policyNumber: policyNumber != null ? Value(policyNumber) : const Value.absent(),
        coveragePercent: coveragePercent != null ? Value(coveragePercent) : const Value.absent(),
        monthlyLimit: monthlyLimit != null ? Value(monthlyLimit) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
        endDate: endDate != null ? Value(endDate) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> addMonthlyUsage(int policyId, double amount) async {
    final row = await (_db.select(_db.insurancePolicies)..where((p) => p.id.equals(policyId))).getSingle();
    await (_db.update(_db.insurancePolicies)..where((p) => p.id.equals(policyId))).write(
      InsurancePoliciesCompanion(monthlyUsed: Value(row.monthlyUsed + amount)),
    );
  }

  @override
  Future<void> resetMonthlyUsage() async {
    await _db.update(_db.insurancePolicies).write(
      const InsurancePoliciesCompanion(monthlyUsed: Value(0)),
    );
  }
}
