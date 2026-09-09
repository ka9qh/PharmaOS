// محرك المساعد السريري وفاحص التداخلات الدوائية والبدائل الذكية - PharmaOS Clinical AI Engine
import 'package:flutter/foundation.dart';
import '../../features/medicines/domain/entities/medicines_entity.dart';
import '../../features/medicines/domain/repositories/medicines_repository.dart';
import '../../core/di/service_locator.dart';

enum InteractionSeverity {
  severe, // خطر شديد 🔴
  moderate, // تحذير متوسط 🟡
  duplicate, // تكرار علاجي لنفس المادة 🟠
  safe, // آمن 🟢
}

class DrugInteractionResult {
  final MedicineEntity medicineA;
  final MedicineEntity medicineB;
  final InteractionSeverity severity;
  final String title;
  final String descriptionAr;
  final String recommendationAr;

  const DrugInteractionResult({
    required this.medicineA,
    required this.medicineB,
    required this.severity,
    required this.title,
    required this.descriptionAr,
    required this.recommendationAr,
  });
}

class ClinicalAiService {
  /// قاموس التداخلات الدوائية السريرية الشائعة والمعتمدة
  static final List<Map<String, dynamic>> _clinicalInteractionRules = [
    // 1. Warfarin / Anticoagulants + NSAIDs / Aspirin
    {
      'drugsA': ['warfarin', 'وارفارين', 'clopidogrel', 'كلوبيدوجريل', 'plavix', 'بلافيكس', 'heparin', 'هيبارين'],
      'drugsB': ['aspirin', 'أسبرين', 'ibuprofen', 'إيبوبروفين', 'diclofenac', 'ديكلوفيناك', 'ketorolac', 'كيتورولاك', 'naproxen', 'نابروكسين', 'meloxicam', 'ميلوكسيكام', 'voltarin', 'فولتارين'],
      'severity': InteractionSeverity.severe,
      'title': 'خطر نزيف حاد (Gastrointestinal Bleeding)',
      'desc': 'الجمع بين مضادات التخثر ومسكنات NSAIDs أو الأسبرين يضاعف بشدة من خطر النزيف المعوي وتثبيط الصفائح الدموية.',
      'recommendation': 'استشر الطبيب، ويُفضل استبدال المسكن بالباراسيتامول (Paracetamol) عند الحاجة لتسكين الألم.',
    },

    // 2. ACE Inhibitors / ARBs + Potassium-sparing Diuretics / K-Supplements
    {
      'drugsA': ['captopril', 'كابتوبريل', 'enalapril', 'إنالابريل', 'lisinopril', 'ليزينوبريل', 'losartan', 'لوسارتان', 'valsartan', 'فالسارتان', 'candesartan', 'كانديسارتان'],
      'drugsB': ['spironolactone', 'سبيرونولاكتون', 'aldactone', 'ألداكتون', 'potassium', 'بوتاسيوم', 'triamterene'],
      'severity': InteractionSeverity.severe,
      'title': 'خطر فرط بوتاسيوم الدم الحاد (Hyperkalemia)',
      'desc': 'أدوية الضغط من فئة مثبطات ACE أو ARBs ترفع مستوى البوتاسيوم في الدم، والجمع بينها وبين مدرات البول الموفرة للبوتاسيوم قد يؤدي لاضطراب خطير في نظم القلب.',
      'recommendation': 'تجنب الجمع دون فحص دوري لمستوى البوتاسيوم ووظائف الكلى.',
    },

    // 3. Sildenafil / PDE5 Inhibitors + Nitrates
    {
      'drugsA': ['sildenafil', 'سيلدينافيل', 'viagra', 'فياجرا', 'tadalafil', 'تادالافيل', 'cialis', 'سياليس', 'vardenafil', 'فاردينافيل'],
      'drugsB': ['nitroglycerin', 'نيتروجليسرين', 'isosorbide', 'إيزوسوربيد', 'nitro', 'angised'],
      'severity': InteractionSeverity.severe,
      'title': 'هبوط حاد وقاتل في ضغط الدم (Severe Hypotension)',
      'desc': 'الجمع بين النيترات وموسعات الأوعية PDE5-inhibitors يسبب هبوطاً حاداً وخطراً في الضغط التاجي قد يؤدي للوفاة.',
      'recommendation': 'ممنوع منعاً باتاً صرف هذا المزيج معاً. يجب إيقاف السيلدينافيل قبل 24-48 ساعة من النيترات.',
    },

    // 4. Macrolides / Fluoroquinolones + Antiarrhythmics / Antihistamines (QT Prolongation)
    {
      'drugsA': ['azithromycin', 'أزيثرومايسين', 'clarithromycin', 'كلاريثرومايسين', 'erythromycin', 'إريثرومايسين', 'ciprofloxacin', 'سيبروفلوكساسين', 'levofloxacin', 'ليفوفلوكساسين'],
      'drugsB': ['amiodarone', 'أميودارون', 'ondansetron', 'أوندانسيترون', 'zofran', 'زفران', 'domperidone', 'دومبيريدون', 'motilium', 'موتيليوم'],
      'severity': InteractionSeverity.moderate,
      'title': 'خطر استطالة فترة QT واضطراب نبض القلب',
      'desc': 'الجمع بين هذه المضادات ومثبطات القيء أو أدوية النبض قد يسبب اضطراباً في التوصيل الكهربائي للقلب.',
      'recommendation': 'ينصح بتباعد الجرعات ومراقبة نبضات القلب أو استخدام بديل مضاد حيوي مناسب.',
    },

    // 5. Antacids / Iron / Calcium + Tetracyclines / Fluoroquinolones
    {
      'drugsA': ['calcium', 'كالسيوم', 'iron', 'حديد', 'ferrous', 'antacid', 'مضاد حموضة', 'maalox', 'مالوكس', 'gaviscon', 'جافيسكون', 'magnesium', 'مغنيسيوم'],
      'drugsB': ['doxycycline', 'دوكسيسيكلين', 'tetracycline', 'تتراسيكلين', 'ciprofloxacin', 'سيبروفلوكساسين', 'levofloxacin', 'ليفوفلوكساسين'],
      'severity': InteractionSeverity.moderate,
      'title': 'انخفاض امتصاص وفعالية المضاد الحيوي (Chelation / Reduced Absorption)',
      'desc': 'المعادن الثنائية والثلاثية تتحد مع المضاد الحيوي في المعدة وتمنع امتصاصه بالكامل.',
      'recommendation': 'يجب الفصل التام وتناول المضاد الحيوي قبل مكملات المعادن بساعتين على الأقل أو بعدها بـ 4 ساعات.',
    },

    // 6. Statins + Fibrates / Gemfibrozil
    {
      'drugsA': ['atorvastatin', 'أتورفاستاتين', 'lipitor', 'ليبيتور', 'simvastatin', 'سيمفاستاتين', 'rosuvastatin', 'روستات'],
      'drugsB': ['gemfibrozil', 'جيمفيبروزيل', 'lopid', 'fenofibrate', 'فينوفيبرات', 'lipanthyl'],
      'severity': InteractionSeverity.moderate,
      'title': 'خطر اعتلال وتحلل العضلات (Rhabdomyolysis)',
      'desc': 'الجمع بين علاجات الدهون يزيد من تركيز الستاتين في الدم وخطر ألم وتلف الألياف العضلية.',
      'recommendation': 'تنبيه المريض للإبلاغ الفوري عند الشعور بآلام عضلية غير مبررة.',
    },

    // 7. Metformin + Iodinated Contrast Agents
    {
      'drugsA': ['metformin', 'ميتفورمين', 'glucophage', 'جلوكوفاج', 'cidophage'],
      'drugsB': ['contrast', 'صبغة', 'iodine', 'يود'],
      'severity': InteractionSeverity.moderate,
      'title': 'خطر الحماض اللبني (Lactic Acidosis)',
      'desc': 'استخدام الصبغات الإشعاعية مع الميتفورمين قد يؤثر مؤقتاً على وظائف الكلى ويزيد تراكم الميتفورمين.',
      'recommendation': 'إيقاف الميتفورمين قبل الفحص بالأشعة بالصبغة بـ 48 ساعة واستئنافه بعد تقييم وظائف الكلى.',
    },
  ];

  /// فحص سلة المبيعات لاكتشاف التداخلات الدوائية والتكرار العلاجي
  static List<DrugInteractionResult> checkInteractions(List<MedicineEntity> cartMedicines) {
    if (cartMedicines.length < 2) return [];

    final results = <DrugInteractionResult>[];

    for (int i = 0; i < cartMedicines.length; i++) {
      for (int j = i + 1; j < cartMedicines.length; j++) {
        final medA = cartMedicines[i];
        final medB = cartMedicines[j];

        // 1. فحص التكرار العلاجي (Duplicate Therapy)
        final duplicateResult = _checkDuplicateTherapy(medA, medB);
        if (duplicateResult != null) {
          results.add(duplicateResult);
        }

        // 2. فحص التداخلات السريرية (Clinical Interactions)
        final interactionResult = _matchClinicalRule(medA, medB);
        if (interactionResult != null) {
          results.add(interactionResult);
        }
      }
    }

    return results;
  }

  /// فحص التكرار العلاجي لنفس المادة الفعالة
  static DrugInteractionResult? _checkDuplicateTherapy(MedicineEntity medA, MedicineEntity medB) {
    final sciA = medA.nameScientific?.trim().toLowerCase() ?? '';
    final sciB = medB.nameScientific?.trim().toLowerCase() ?? '';

    // إذا كانت المادة الفعالة متطابقة وهما دواءان مختلفان
    if (sciA.isNotEmpty && sciB.isNotEmpty && sciA == sciB && medA.id != medB.id) {
      return DrugInteractionResult(
        medicineA: medA,
        medicineB: medB,
        severity: InteractionSeverity.duplicate,
        title: 'تكرار علاجي لنفس المادة الفعالة ($sciA)',
        descriptionAr: 'الدواءان [${medA.nameAr}] و [${medB.nameAr}] يحتويان على نفس المادة الفعالة، مما قد يعرض المريض لمضاعفات فرط الجرعة (Overdose).',
        recommendationAr: 'تأكد من أن الطبيب لم يقصد صرف أحدهما فقط كبديل للآخر.',
      );
    }

    // فحص الباراسيتامول المدمج
    final nameA = (medA.nameAr + (medA.nameEn ?? '')).toLowerCase();
    final nameB = (medB.nameAr + (medB.nameEn ?? '')).toLowerCase();

    final isParacetamolA = nameA.contains('paracetamol') || nameA.contains('باراسيتامول') || nameA.contains('panadol') || nameA.contains('بنادول') || nameA.contains('paramol') || nameA.contains('بارامول') || nameA.contains('ad褐') || nameA.contains('fever');
    final isParacetamolB = nameB.contains('paracetamol') || nameB.contains('باراسيتامول') || nameB.contains('panadol') || nameB.contains('بنادول') || nameB.contains('paramol') || nameB.contains('بارامول') || nameB.contains('ad褐') || nameB.contains('fever');

    if (isParacetamolA && isParacetamolB && medA.id != medB.id) {
      return DrugInteractionResult(
        medicineA: medA,
        medicineB: medB,
        severity: InteractionSeverity.duplicate,
        title: 'تحذير تكرار مركب الباراسيتامول (Paracetamol Toxicity Risk)',
        descriptionAr: 'الدواءان يحتويان على مركب الباراسيتامول. تناول أكثر من منتج يحتوي على الباراسيتامول في نفس الوقت قد يتجاوز الجرعة الآمنة (4000 ملجم يومياً) ويسبب سمية كبدية.',
        recommendationAr: 'نبه المريض بعدم الجمع بينهما في نفس وقت تناول الجرعة.',
      );
    }

    return null;
  }

  /// مطابقة القواعد السريرية
  static DrugInteractionResult? _matchClinicalRule(MedicineEntity medA, MedicineEntity medB) {
    final textA = '${medA.nameAr} ${medA.nameEn ?? ''} ${medA.nameScientific ?? ''}'.toLowerCase();
    final textB = '${medB.nameAr} ${medB.nameEn ?? ''} ${medB.nameScientific ?? ''}'.toLowerCase();

    for (final rule in _clinicalInteractionRules) {
      final List<String> listA = rule['drugsA'];
      final List<String> listB = rule['drugsB'];

      final matchAInListA = listA.any((term) => textA.contains(term.toLowerCase()));
      final matchBInListB = listB.any((term) => textB.contains(term.toLowerCase()));

      final matchBInListA = listA.any((term) => textB.contains(term.toLowerCase()));
      final matchAInListB = listB.any((term) => textA.contains(term.toLowerCase()));

      if ((matchAInListA && matchBInListB) || (matchBInListA && matchAInListB)) {
        return DrugInteractionResult(
          medicineA: medA,
          medicineB: medB,
          severity: rule['severity'] as InteractionSeverity,
          title: rule['title'] as String,
          descriptionAr: rule['desc'] as String,
          recommendationAr: rule['recommendation'] as String,
        );
      }
    }

    return null;
  }

  /// البحث عن البدائل الذكية المتوفرة في الصيدلية بنفس المادة الفعالة
  static Future<List<MedicineEntity>> findSmartAlternatives(MedicineEntity targetMedicine) async {
    final repo = sl<MedicinesRepository>();
    final sciName = targetMedicine.nameScientific?.trim() ?? '';

    if (sciName.isNotEmpty) {
      final alternatives = await repo.getAlternatives(targetMedicine.id, sciName);
      if (alternatives.isNotEmpty) return alternatives;
    }

    // محاولة البحث بالاسم الشائع إذا غاب الاسم العلمي
    final firstWord = targetMedicine.nameAr.split(' ').first;
    if (firstWord.length >= 3) {
      final searchResults = await repo.getAll(searchQuery: firstWord);
      return searchResults.where((m) => m.id != targetMedicine.id).take(15).toList();
    }

    return [];
  }
}
