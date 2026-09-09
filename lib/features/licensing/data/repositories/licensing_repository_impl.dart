import '../../domain/entities/licensing_entity.dart';
import '../../domain/repositories/licensing_repository.dart';
import '../datasources/licensing_datasource.dart';
import '../../../../core/security/audit_logger.dart';

class LicensingRepositoryImpl implements LicensingRepository {
  final LicensingDataSource dataSource;
  final AuditLogger auditLogger;

  LicensingRepositoryImpl({required this.dataSource, required this.auditLogger});

  @override
  Future<String> getHardwareId() => dataSource.getHardwareId();

  @override
  Future<bool> hasValidLicense() => dataSource.hasValidLicense();

  @override
  Future<LicenseValidationOutcome> activate(String licenseKey) async {
    final outcome = await dataSource.activate(licenseKey);
    await auditLogger.log(
      actionType: outcome.isValid ? 'LICENSE_ACTIVATED' : 'LICENSE_ACTIVATION_FAILED',
      tableName: 'licenses',
      newValue: outcome.isValid ? 'pharmacy=${outcome.payload?.pharmacyName}' : outcome.result.name,
    );
    return outcome;
  }
}
