/// خدمة النقل الصوتي (Transliteration) لأسماء الأدوية من الإنجليزية إلى العربية.
/// تحوّل الاسم الإنجليزي لنطقه العربي الصيدلاني المتعارف عليه.
/// مثال: Paracetamol → باراسيتامول، Amoxicillin → أموكسيسيللين
class ArabicTransliterator {
  // قاموس الأسماء التجارية الشائعة (أهم 300+ دواء في الصيدليات العربية)
  static const Map<String, String> _knownBrands = {
    // مسكنات وخافضات حرارة
    'panadol': 'بنادول', 'paracetamol': 'باراسيتامول', 'acetaminophen': 'أسيتامينوفين',
    'aspirin': 'أسبرين', 'ibuprofen': 'إيبوبروفين', 'brufen': 'بروفين',
    'voltaren': 'فولتارين', 'diclofenac': 'ديكلوفيناك', 'ketoprofen': 'كيتوبروفين',
    'naproxen': 'نابروكسين', 'celecoxib': 'سيليكوكسيب', 'piroxicam': 'بيروكسيكام',
    'tramadol': 'ترامادول', 'morphine': 'مورفين', 'codeine': 'كودايين',
    'meloxicam': 'ميلوكسيكام', 'etoricoxib': 'إيتوريكوكسيب',
    // مضادات حيوية
    'amoxicillin': 'أموكسيسيللين', 'augmentin': 'أوجمنتين', 'amoxil': 'أموكسيل',
    'azithromycin': 'أزيثروميسين', 'zithromax': 'زيثروماكس',
    'ciprofloxacin': 'سيبروفلوكساسين', 'cipro': 'سيبرو',
    'cephalexin': 'سيفالكسين', 'cefixime': 'سيفيكسيم', 'ceftriaxone': 'سيفترياكسون',
    'metronidazole': 'ميترونيدازول', 'flagyl': 'فلاجيل',
    'doxycycline': 'دوكسيسيكلين', 'tetracycline': 'تيتراسيكلين',
    'erythromycin': 'إريثروميسين', 'clarithromycin': 'كلاريثروميسين',
    'levofloxacin': 'ليفوفلوكساسين', 'moxifloxacin': 'موكسيفلوكساسين',
    'clindamycin': 'كليندامايسين', 'vancomycin': 'فانكومايسين',
    'gentamicin': 'جنتامايسين', 'tobramycin': 'توبرامايسين',
    'penicillin': 'بنسيلين', 'ampicillin': 'أمبيسيللين',
    'cefuroxime': 'سيفوروكسيم', 'cefotaxime': 'سيفوتاكسيم',
    'cefepime': 'سيفيبيم', 'cefpodoxime': 'سيفبودوكسيم',
    'nitrofurantoin': 'نيتروفورانتوين', 'trimethoprim': 'تريميثوبريم',
    'sulfamethoxazole': 'سلفاميثوكسازول', 'linezolid': 'لينزوليد',
    // أدوية الضغط والقلب
    'amlodipine': 'أملوديبين', 'atenolol': 'أتينولول', 'bisoprolol': 'بيسوبرولول',
    'captopril': 'كابتوبريل', 'enalapril': 'إنالابريل', 'lisinopril': 'ليسينوبريل',
    'losartan': 'لوسارتان', 'valsartan': 'فالسارتان', 'telmisartan': 'تيلميسارتان',
    'nifedipine': 'نيفيديبين', 'diltiazem': 'ديلتيازيم', 'verapamil': 'فيراباميل',
    'propranolol': 'بروبرانولول', 'carvedilol': 'كارفيديلول',
    'hydrochlorothiazide': 'هيدروكلوروثيازيد', 'furosemide': 'فوروسيميد',
    'spironolactone': 'سبيرونولاكتون', 'indapamide': 'إنداباميد',
    'digoxin': 'ديجوكسين', 'warfarin': 'وارفارين', 'clopidogrel': 'كلوبيدوجريل',
    'rivaroxaban': 'ريفاروكسابان', 'apixaban': 'أبيكسابان',
    // أدوية السكري
    'metformin': 'ميتفورمين', 'glimepiride': 'جليمبيريد', 'glibenclamide': 'جليبينكلاميد',
    'insulin': 'إنسولين', 'sitagliptin': 'سيتاجلبتين', 'januvia': 'جانوفيا',
    'empagliflozin': 'إمباجليفلوزين', 'dapagliflozin': 'داباجليفلوزين',
    'pioglitazone': 'بيوجليتازون', 'gliclazide': 'جليكلازيد',
    // أدوية المعدة
    'omeprazole': 'أوميبرازول', 'esomeprazole': 'إيسوميبرازول',
    'lansoprazole': 'لانسوبرازول', 'pantoprazole': 'بانتوبرازول',
    'rabeprazole': 'رابيبرازول', 'ranitidine': 'رانيتيدين',
    'famotidine': 'فاموتيدين', 'domperidone': 'دومبيريدون',
    'metoclopramide': 'ميتوكلوبراميد', 'antacid': 'مضاد للحموضة',
    'gaviscon': 'جافيسكون', 'nexium': 'نيكسيوم',
    // أدوية الحساسية والتنفس
    'cetirizine': 'سيتريزين', 'loratadine': 'لوراتادين', 'fexofenadine': 'فيكسوفينادين',
    'chlorpheniramine': 'كلورفينيرامين', 'diphenhydramine': 'ديفينهيدرامين',
    'salbutamol': 'سالبيوتامول', 'ventolin': 'فنتولين',
    'budesonide': 'بوديسونيد', 'fluticasone': 'فلوتيكازون',
    'montelukast': 'مونتيلوكاست', 'singulair': 'سنجولير',
    'theophylline': 'ثيوفيلين', 'aminophylline': 'أمينوفيلين',
    'pseudoephedrine': 'سودوإيفيدرين', 'dextromethorphan': 'ديكستروميثورفان',
    'guaifenesin': 'جوايفينيسين', 'bromhexine': 'برومهيكسين',
    'ambroxol': 'أمبروكسول',
    // فيتامينات ومعادن
    'vitamin': 'فيتامين', 'calcium': 'كالسيوم', 'iron': 'حديد',
    'zinc': 'زنك', 'magnesium': 'ماغنيسيوم', 'folic': 'فوليك',
    'omega': 'أوميغا', 'multivitamin': 'ملتي فيتامين',
    // مضادات الفطريات
    'fluconazole': 'فلوكونازول', 'itraconazole': 'إتراكونازول',
    'ketoconazole': 'كيتوكونازول', 'clotrimazole': 'كلوتريمازول',
    'miconazole': 'ميكونازول', 'nystatin': 'نيستاتين',
    'terbinafine': 'تيربينافين',
    // أدوية الاكتئاب والأعصاب
    'sertraline': 'سيرترالين', 'fluoxetine': 'فلوكسيتين',
    'escitalopram': 'إسيتالوبرام', 'paroxetine': 'باروكسيتين',
    'amitriptyline': 'أميتريبتيلين', 'carbamazepine': 'كاربامازيبين',
    'gabapentin': 'جابابنتين', 'pregabalin': 'بريجابالين',
    'diazepam': 'ديازيبام', 'alprazolam': 'ألبرازولام',
    'clonazepam': 'كلونازيبام', 'phenobarbital': 'فينوباربيتال',
    'phenytoin': 'فينيتوين', 'valproic': 'فالبرويك',
    'levetiracetam': 'ليفيتيراسيتام', 'topiramate': 'توبيراميت',
    // أدوية العيون
    'tobradex': 'توبراديكس', 'timolol': 'تيمولول',
    'latanoprost': 'لاتانوبروست', 'brimonidine': 'بريمونيدين',
    // الكورتيزونات
    'prednisolone': 'بريدنيزولون', 'prednisone': 'بريدنيزون',
    'dexamethasone': 'ديكساميثازون', 'hydrocortisone': 'هيدروكورتيزون',
    'betamethasone': 'بيتاميثازون', 'triamcinolone': 'تريامسينولون',
    'methylprednisolone': 'ميثيل بريدنيزولون', 'cortisone': 'كورتيزون',
    // أدوية الكولسترول
    'atorvastatin': 'أتورفاستاتين', 'rosuvastatin': 'روسوفاستاتين',
    'simvastatin': 'سيمفاستاتين', 'pravastatin': 'برافاستاتين',
    'lipitor': 'ليبيتور', 'crestor': 'كريستور',
    // مضادات القيء
    'ondansetron': 'أوندانسيترون', 'granisetron': 'جرانيسيترون',
    // أدوية أخرى شائعة
    'albendazole': 'ألبيندازول', 'mebendazole': 'ميبيندازول',
    'ivermectin': 'إيفرمكتين', 'praziquantel': 'برازيكوانتيل',
    'sildenafil': 'سيلدينافيل', 'tadalafil': 'تادالافيل',
    'tamsulosin': 'تامسولوسين', 'finasteride': 'فيناسترايد',
    'levothyroxine': 'ليفوثيروكسين', 'propylthiouracil': 'بروبيل ثيوراسيل',
    'allopurinol': 'ألوبيورينول', 'colchicine': 'كولشيسين',
    'hydroxychloroquine': 'هيدروكسي كلوروكين', 'chloroquine': 'كلوروكين',
    'acyclovir': 'أسيكلوفير', 'valacyclovir': 'فالاسيكلوفير',
    'oseltamivir': 'أوسيلتاميفير',
    'acetylcysteine': 'أسيتيل سيستين', 'mucolytic': 'مذيب للبلغم',
    'loperamide': 'لوبيراميد', 'imodium': 'إيموديوم',
    'lactulose': 'لاكتولوز', 'bisacodyl': 'بيساكوديل',
    'sucralfate': 'سوكرالفيت', 'misoprostol': 'ميسوبروستول',
    'methyldopa': 'ميثيل دوبا', 'hydralazine': 'هيدرالازين',
    'nitroglycerin': 'نيتروجليسرين', 'isosorbide': 'آيزوسوربيد',
    'dopamine': 'دوبامين', 'dobutamine': 'دوبيوتامين', 'adrenaline': 'أدرينالين',
    'epinephrine': 'إبينفرين', 'atropine': 'أتروبين',
    'lidocaine': 'ليدوكايين', 'bupivacaine': 'بوبيفاكايين',
    'heparin': 'هيبارين', 'enoxaparin': 'إينوكسابارين',
    'tranexamic': 'ترانيكساميك', 'ferrous': 'فيروس',
    'dexlansoprazole': 'ديكسلانسوبرازول',
  };

  /// خريطة الأحرف للنقل الصوتي (transliteration) - للأسماء غير الموجودة في القاموس
  static const Map<String, String> _charMap = {
    'a': 'ا', 'b': 'ب', 'c': 'ك', 'd': 'د', 'e': 'ي',
    'f': 'ف', 'g': 'ج', 'h': 'ه', 'i': 'ي', 'j': 'ج',
    'k': 'ك', 'l': 'ل', 'm': 'م', 'n': 'ن', 'o': 'و',
    'p': 'ب', 'q': 'ك', 'r': 'ر', 's': 'س', 't': 'ت',
    'u': 'و', 'v': 'ف', 'w': 'و', 'x': 'كس', 'y': 'ي',
    'z': 'ز',
  };

  /// مقاطع صوتية شائعة في أسماء الأدوية
  static const Map<String, String> _syllableMap = {
    'ph': 'ف', 'th': 'ث', 'ch': 'تش', 'sh': 'ش',
    'tion': 'شن', 'sion': 'جن', 'ine': 'ين', 'ene': 'ين',
    'ol': 'ول', 'al': 'ال', 'il': 'يل', 'el': 'يل',
    'an': 'ان', 'en': 'ين', 'in': 'ين', 'on': 'ون', 'un': 'ون',
    'am': 'ام', 'em': 'يم', 'im': 'يم', 'om': 'وم', 'um': 'وم',
    'ar': 'ار', 'er': 'ير', 'ir': 'ير', 'or': 'ور', 'ur': 'ور',
    'ate': 'ات', 'ide': 'ايد', 'ose': 'وز', 'ase': 'از',
    'yl': 'يل', 'ic': 'يك', 'oc': 'وك',
    'oo': 'و', 'ee': 'ي', 'ea': 'يا', 'ou': 'او',
    'ck': 'ك', 'ss': 'س', 'tt': 'ت', 'll': 'ل',
    'mm': 'م', 'nn': 'ن', 'pp': 'ب', 'rr': 'ر',
    'ff': 'ف', 'dd': 'د', 'bb': 'ب', 'gg': 'ج',
    'zz': 'ز', 'cc': 'ك',
  };

  /// يحوّل اسم الدواء الإنجليزي إلى نطقه العربي
  static String transliterate(String englishName) {
    if (englishName.trim().isEmpty) return '';

    // إذا كان الاسم يحتوي على حروف عربية أصلاً، أرجعه كما هو
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(englishName)) {
      return englishName;
    }

    final words = englishName.split(RegExp(r'[\s+\-/]+'));
    final arabicWords = <String>[];

    for (final word in words) {
      final clean = word.replaceAll(RegExp(r'[^a-zA-Z0-9.%]'), '').toLowerCase();
      if (clean.isEmpty) continue;

      // أرقام ورموز تبقى كما هي
      if (RegExp(r'^[0-9.%]+$').hasMatch(clean)) {
        arabicWords.add(word);
        continue;
      }

      // بحث في قاموس الأسماء المعروفة
      final known = _knownBrands[clean];
      if (known != null) {
        arabicWords.add(known);
        continue;
      }

      // نقل صوتي حرف بحرف مع مراعاة المقاطع
      arabicWords.add(_transliterateWord(clean));
    }

    final result = arabicWords.join(' ');
    return result.isEmpty ? englishName : result;
  }

  static String _transliterateWord(String word) {
    final buffer = StringBuffer();
    var i = 0;

    while (i < word.length) {
      if (i < word.length - 1) {
        // محاولة مطابقة مقطع من 4 أحرف
        if (i < word.length - 3) {
          final quad = word.substring(i, i + 4);
          if (_syllableMap.containsKey(quad)) {
            buffer.write(_syllableMap[quad]);
            i += 4;
            continue;
          }
        }
        // محاولة مطابقة مقطع من 3 أحرف
        if (i < word.length - 2) {
          final triple = word.substring(i, i + 3);
          if (_syllableMap.containsKey(triple)) {
            buffer.write(_syllableMap[triple]);
            i += 3;
            continue;
          }
        }
        // محاولة مطابقة مقطع من حرفين
        final pair = word.substring(i, i + 2);
        if (_syllableMap.containsKey(pair)) {
          buffer.write(_syllableMap[pair]);
          i += 2;
          continue;
        }
      }

      // حرف واحد
      final ch = word[i];
      buffer.write(_charMap[ch] ?? ch);
      i++;
    }

    return buffer.toString();
  }
}
