class SuppliersController {
  SuppliersController._();

  static String? validateName(String name) {
    if (name.trim().isEmpty) return 'ط§ظ„ط±ط¬ط§ط، ط¥ط¯ط®ط§ظ„ ط§ط³ظ… ط§ظ„ظ…ظˆط±ط¯';
    if (name.trim().length > 150) return 'ط§ظ„ط§ط³ظ… ط·ظˆظٹظ„ ط¬ط¯ظ‹ط§';
    return null;
  }
}
