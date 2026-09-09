import '../entities/settings_entity.dart';
import '../repositories/settings_repository.dart';

class LoadSettingsUseCase {
  final SettingsRepository _repo;
  const LoadSettingsUseCase(this._repo);
  Future<PharmacySettings> call() => _repo.load();
}

class SaveSettingsUseCase {
  final SettingsRepository _repo;
  const SaveSettingsUseCase(this._repo);
  Future<void> call(PharmacySettings settings) => _repo.save(settings);
}
