import '../entities/settings_entity.dart';

abstract class SettingsRepository {
  Future<PharmacySettings> load();
  Future<void> save(PharmacySettings settings);
}
