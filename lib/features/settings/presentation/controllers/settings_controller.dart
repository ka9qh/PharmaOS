class SettingsController {
  SettingsController._();

  static String? validatePharmacyName(String name) {
    return name.trim().isEmpty ? 'ط§ظ„ط±ط¬ط§ط، ط¥ط¯ط®ط§ظ„ ط§ط³ظ… ط§ظ„طµظٹط¯ظ„ظٹط©' : null;
  }

  static String? validateReorderLevel(String text) {
    final value = int.tryParse(text);
    return (value == null || value < 0) ? 'ط±ظ‚ظ… ط؛ظٹط± طµط§ظ„ط­' : null;
  }
}
