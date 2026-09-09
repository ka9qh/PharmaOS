import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/settings_entity.dart';

class SettingsDataSource {
  final AppDatabase _db;
  SettingsDataSource(this._db);

  static const _keyPharmacyName = 'pharmacy_name';
  static const _keyPharmacyPhone = 'pharmacy_phone';
  static const _keyCurrencyLabel = 'currency_label';
  static const _keyDefaultReorderLevel = 'default_reorder_level';
  static const _keyDisabledModules = 'disabled_modules';
  static const _keySavePath = 'save_path';
  static const _keySaveFormat = 'save_format';
  static const _keyWalletPaymentTypes = 'wallet_payment_types';
  static const _keyIsMultiCurrencyEnabled = 'is_multi_currency_enabled';
  static const _keyIsNotificationsEnabled = 'is_notifications_enabled';
  
  static const _keyTaxEnabled = 'tax_enabled';
  static const _keyTaxRate = 'tax_rate';

  Future<String?> _get(String key) async {
    final row = await (_db.select(_db.settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _set(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  }

  Future<PharmacySettings> load() async {
    final settings = PharmacySettings(
      pharmacyName: await _get(_keyPharmacyName) ?? '',
      pharmacyPhone: await _get(_keyPharmacyPhone) ?? '',
      currencyLabel: await _get(_keyCurrencyLabel) ?? 'ريال',
      defaultReorderLevel: int.tryParse(await _get(_keyDefaultReorderLevel) ?? '') ?? 5,
      disabledModules: (await _get(_keyDisabledModules))?.split(',').where((e) => e.isNotEmpty).toList() ?? [],
      savePath: await _get(_keySavePath) ?? 'C:\\PharmaOS_Files',
      saveFormat: await _get(_keySaveFormat) ?? 'PDF',
      walletPaymentTypes: (await _get(_keyWalletPaymentTypes))?.split(',').where((e) => e.isNotEmpty).toList() ?? ['نقدي', 'بطاقة ائتمان', 'حوالة بنكية'],
      isMultiCurrencyEnabled: (await _get(_keyIsMultiCurrencyEnabled)) == 'true',
      isNotificationsEnabled: (await _get(_keyIsNotificationsEnabled)) != 'false',
      taxEnabled: (await _get(_keyTaxEnabled)) == 'true',
      taxRate: double.tryParse(await _get(_keyTaxRate) ?? '') ?? 15.0,
    );
    // تحديث القيمة الثابتة المستخدمة في CurrencyFormatter فور تحميل الإعدادات
    CurrencyFormatter.currentSymbol = settings.currencyLabel;
    return settings;
  }

  Future<void> save(PharmacySettings settings) async {
    await _set(_keyPharmacyName, settings.pharmacyName);
    await _set(_keyPharmacyPhone, settings.pharmacyPhone);
    await _set(_keyCurrencyLabel, settings.currencyLabel);
    await _set(_keyDefaultReorderLevel, settings.defaultReorderLevel.toString());
    await _set(_keyDisabledModules, settings.disabledModules.join(','));
    await _set(_keySavePath, settings.savePath);
    await _set(_keySaveFormat, settings.saveFormat);
    await _set(_keyWalletPaymentTypes, settings.walletPaymentTypes.join(','));
    await _set(_keyIsMultiCurrencyEnabled, settings.isMultiCurrencyEnabled.toString());
    await _set(_keyIsNotificationsEnabled, settings.isNotificationsEnabled.toString());
    await _set(_keyTaxEnabled, settings.taxEnabled.toString());
    await _set(_keyTaxRate, settings.taxRate.toString());
    CurrencyFormatter.currentSymbol = settings.currencyLabel;
  }
}
