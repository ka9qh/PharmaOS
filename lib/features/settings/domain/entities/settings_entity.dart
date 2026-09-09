class PharmacySettings {
  final String pharmacyName;
  final String pharmacyPhone;
  final String currencyLabel;
  final int defaultReorderLevel;
  
  // Step 21 fields
  final List<String> disabledModules;
  final String savePath;
  final String saveFormat;
  final List<String> walletPaymentTypes;
  final bool isMultiCurrencyEnabled;
  final bool isNotificationsEnabled;
  final bool deductAbsenceFromSalary;
  final double absenceDeductionAmount;
  
  // Tax settings
  final bool taxEnabled;
  final double taxRate;

  const PharmacySettings({
    this.pharmacyName = '',
    this.pharmacyPhone = '',
    this.currencyLabel = 'ريال',
    this.defaultReorderLevel = 5,
    this.disabledModules = const [],
    this.savePath = 'C:\\PharmaOS_Files',
    this.saveFormat = 'PDF',
    this.walletPaymentTypes = const ['نقدي', 'بطاقة ائتمان', 'حوالة بنكية'],
    this.isMultiCurrencyEnabled = false,
    this.isNotificationsEnabled = true,
    this.deductAbsenceFromSalary = false,
    this.absenceDeductionAmount = 0.0,
    this.taxEnabled = false,
    this.taxRate = 15.0,
  });

  PharmacySettings copyWith({
    String? pharmacyName,
    String? pharmacyPhone,
    String? currencyLabel,
    int? defaultReorderLevel,
    List<String>? disabledModules,
    String? savePath,
    String? saveFormat,
    List<String>? walletPaymentTypes,
    bool? isMultiCurrencyEnabled,
    bool? isNotificationsEnabled,
    bool? deductAbsenceFromSalary,
    double? absenceDeductionAmount,
    bool? taxEnabled,
    double? taxRate,
  }) {
    return PharmacySettings(
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyPhone: pharmacyPhone ?? this.pharmacyPhone,
      currencyLabel: currencyLabel ?? this.currencyLabel,
      defaultReorderLevel: defaultReorderLevel ?? this.defaultReorderLevel,
      disabledModules: disabledModules ?? this.disabledModules,
      savePath: savePath ?? this.savePath,
      saveFormat: saveFormat ?? this.saveFormat,
      walletPaymentTypes: walletPaymentTypes ?? this.walletPaymentTypes,
      isMultiCurrencyEnabled: isMultiCurrencyEnabled ?? this.isMultiCurrencyEnabled,
      isNotificationsEnabled: isNotificationsEnabled ?? this.isNotificationsEnabled,
      deductAbsenceFromSalary: deductAbsenceFromSalary ?? this.deductAbsenceFromSalary,
      absenceDeductionAmount: absenceDeductionAmount ?? this.absenceDeductionAmount,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}
