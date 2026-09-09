class ReturnsController {
  ReturnsController._();

  static String? validateQuantity(String text, int maxReturnable) {
    final value = int.tryParse(text);
    if (value == null || value <= 0) return 'ظƒظ…ظٹط© ط؛ظٹط± طµط§ظ„ط­ط©';
    if (value > maxReturnable) return 'ط£ظƒط¨ط± ظ…ظ† ط§ظ„ط­ط¯ ط§ظ„ظ…ط³ظ…ظˆط­ ($maxReturnable)';
    return null;
  }
}
