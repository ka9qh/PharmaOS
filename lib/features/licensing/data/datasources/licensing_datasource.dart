// يتعامل مباشرة مع core/licensing (توليد المعرف والتحقق) وجدول licenses.

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/licensing/hardware_id_generator.dart';
import '../../../../core/licensing/license_validator.dart';

class LicensingDataSource {
  final AppDatabase _db;
  LicensingDataSource(this._db);

  Future<String> getHardwareId() => HardwareIdGenerator.getHardwareId();

  Future<LicenseRow?> _getStoredLicense() {
    return (_db.select(_db.licenses)
          ..orderBy([(l) => OrderingTerm.desc(l.activatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<bool> hasValidLicense() async {
    final stored = await _getStoredLicense();
    if (stored == null) return false;

    final hwid = await getHardwareId();
    final outcome = LicenseValidator.validate(stored.licenseKey, currentHardwareId: hwid);
    return outcome.isValid;
  }

  Future<LicenseValidationOutcome> activate(String licenseKey) async {
    final hwid = await getHardwareId();
    final outcome = LicenseValidator.validate(licenseKey, currentHardwareId: hwid);

    if (outcome.isValid && outcome.payload != null) {
      // ترخيص واحد فعّال فقط لكل تثبيت - نحذف أي ترخيص سابق قبل حفظ الجديد
      await _db.delete(_db.licenses).go();

      await _db.into(_db.licenses).insert(
            LicensesCompanion.insert(
              hardwareId: hwid,
              licenseKey: licenseKey,
              pharmacyName: outcome.payload!.pharmacyName,
              expiresAt: Value(outcome.payload!.expiresAt),
            ),
          );
    }

    return outcome;
  }
}
