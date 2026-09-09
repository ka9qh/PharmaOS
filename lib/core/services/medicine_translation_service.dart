class MedicineTranslationService {
  static const Map<String, String> _commonTerms = {
    'syrup': 'شراب',
    'syr': 'شراب',
    'tablet': 'أقراص',
    'tablets': 'أقراص',
    'tab': 'أقراص',
    'tabs': 'أقراص',
    'capsule': 'كبسول',
    'capsules': 'كبسول',
    'cap': 'كبسول',
    'caps': 'كبسول',
    'injection': 'حقنة',
    'inj': 'حقنة',
    'ampoule': 'أمبولة',
    'amp': 'أمبولة',
    'vial': 'فيال',
    'ointment': 'مرهم',
    'oint': 'مرهم',
    'cream': 'كريم',
    'crm': 'كريم',
    'gel': 'جل',
    'lotion': 'لوشن',
    'drops': 'قطرة',
    'drop': 'قطرة',
    'drp': 'قطرة',
    'suspension': 'معلق',
    'susp': 'معلق',
    'suppository': 'تحميلة',
    'suppositories': 'تحاميل',
    'supp': 'تحاميل',
    'powder': 'مسحوق',
    'sachet': 'كيس',
    'sachets': 'أكياس',
    'spray': 'بخاخ',
    'inhaler': 'بخاخ',
    'solution': 'محلول',
    'sol': 'محلول',
    'mg': 'مجم',
    'ml': 'مل',
    'g': 'جم',
    'mcg': 'ميكروجرام',
    'iu': 'وحدة دولية',
    'children': 'أطفال',
    'adult': 'كبار',
    'infant': 'رضع',
    'forte': 'فورت',
    'plus': 'بلس',
    'extra': 'إكسترا',
  };

  static String translate(String englishName) {
    if (englishName.trim().isEmpty) return '';
    
    final words = englishName.toLowerCase().split(RegExp(r'\s+'));
    final translatedWords = <String>[];
    bool hasTranslation = false;

    for (var word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^a-z0-9]'), '');
      
      if (_commonTerms.containsKey(cleanWord)) {
        final suffix = word.replaceAll(cleanWord, '');
        translatedWords.add(_commonTerms[cleanWord]! + suffix);
        hasTranslation = true;
      } else if (RegExp(r'^[0-9]+$').hasMatch(cleanWord)) {
        translatedWords.add(word);
      } else {
        translatedWords.add(word);
      }
    }

    if (!hasTranslation) {
      return ''; 
    }

    return translatedWords.join(' ');
  }
}
