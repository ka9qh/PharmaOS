import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_datasource.dart';
import '../../../../core/security/audit_logger.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsDataSource dataSource;
  final AuditLogger auditLogger;

  SettingsRepositoryImpl({required this.dataSource, required this.auditLogger});

  @override
  Future<PharmacySettings> load() => dataSource.load();

  @override
  Future<void> save(PharmacySettings settings) async {
    await dataSource.save(settings);
    await auditLogger.log(
      actionType: 'SETTINGS_UPDATED',
      tableName: 'settings',
      newValue: 'pharmacy=${settings.pharmacyName}, currency=${settings.currencyLabel}',
    );
  }
}
