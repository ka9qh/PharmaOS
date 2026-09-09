import '../entities/licensing_entity.dart';
import '../repositories/licensing_repository.dart';

class GetHardwareIdUseCase {
  final LicensingRepository _repo;
  const GetHardwareIdUseCase(this._repo);
  Future<String> call() => _repo.getHardwareId();
}

class HasValidLicenseUseCase {
  final LicensingRepository _repo;
  const HasValidLicenseUseCase(this._repo);
  Future<bool> call() => _repo.hasValidLicense();
}

class ActivateLicenseUseCase {
  final LicensingRepository _repo;
  const ActivateLicenseUseCase(this._repo);
  Future<LicenseValidationOutcome> call(String licenseKey) => _repo.activate(licenseKey);
}
