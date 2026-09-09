import 'package:flutter/material.dart';

// خدمة الإرشادات السريرية والوصفات الطبية ومأمونية الحوامل ومرضى القلب والبدائل الآمنة - PharmaOS

class ClinicalPrescriptionInfo {
  final String indications; // دواعي الاستعمال
  final String adultDosage; // جرعة البالغين
  final String pediatricDosage; // جرعة الأطفال
  final String instructions; // طريقة الاستخدام والتحذيرات

  const ClinicalPrescriptionInfo({
    required this.indications,
    required this.adultDosage,
    required this.pediatricDosage,
    required this.instructions,
  });
}

class PregnancySafetyInfo {
  final bool isSafe; // هل هو مسموح للحوامل
  final String statusLabel; // نص حالة المأمونية
  final String riskExplanation; // تفاصيل المخاطر والأسباب السريرية
  final String safeAlternative; // البديل الآمن الموصى به طبياً للحوامل
  final Color statusColor;

  const PregnancySafetyInfo({
    required this.isSafe,
    required this.statusLabel,
    required this.riskExplanation,
    required this.safeAlternative,
    required this.statusColor,
  });
}

class CardiacSafetyInfo {
  final bool isSafe; // هل هو آمن لمرضى القلب والضغط
  final String statusLabel; // نص حالة المأمونية
  final String riskExplanation; // تفاصيل التأثير على القلب والضغط
  final String safeAlternative; // البديل الآمن الموصى به لمرضى القلب والضغط
  final Color statusColor;

  const CardiacSafetyInfo({
    required this.isSafe,
    required this.statusLabel,
    required this.riskExplanation,
    required this.safeAlternative,
    required this.statusColor,
  });
}

class GeneralContraindicationsInfo {
  final List<String> warnings; // تحذيرات الكلى، الكبد، الربو، وقرحة المعدة

  const GeneralContraindicationsInfo({required this.warnings});
}

class FullClinicalProfile {
  final ClinicalPrescriptionInfo prescription;
  final PregnancySafetyInfo pregnancy;
  final CardiacSafetyInfo cardiac;
  final GeneralContraindicationsInfo generalWarnings;

  const FullClinicalProfile({
    required this.prescription,
    required this.pregnancy,
    required this.cardiac,
    required this.generalWarnings,
  });
}

class MedicineClinicalHelper {
  /// تحليل الملف السريري الشامل (الوصفة، الحوامل، مرضى القلب، التحذيرات، والبدائل)
  static FullClinicalProfile getFullClinicalProfile({
    required String medicineName,
    String? scientificName,
    String? categoryName,
    String? rawReserve1,
    String? formOrPack,
  }) {
    final prescription = getPrescriptionDetails(
      medicineName: medicineName,
      scientificName: scientificName,
      categoryName: categoryName,
      rawReserve1: rawReserve1,
      formOrPack: formOrPack,
    );

    final pregnancy = getPregnancySafety(
      medicineName: medicineName,
      scientificName: scientificName,
      categoryName: categoryName,
    );

    final cardiac = getCardiacSafety(
      medicineName: medicineName,
      scientificName: scientificName,
      categoryName: categoryName,
    );

    final generalWarnings = getGeneralContraindications(
      medicineName: medicineName,
      scientificName: scientificName,
      categoryName: categoryName,
    );

    return FullClinicalProfile(
      prescription: prescription,
      pregnancy: pregnancy,
      cardiac: cardiac,
      generalWarnings: generalWarnings,
    );
  }

  /// تحليل مأمونية الدواء للحوامل وتحديد البديل الآمن
  static PregnancySafetyInfo getPregnancySafety({
    required String medicineName,
    String? scientificName,
    String? categoryName,
  }) {
    final medLower = medicineName.toLowerCase();
    final sciLower = (scientificName ?? '').toLowerCase();
    final catLower = (categoryName ?? '').toLowerCase();

    // 1. ميسوبروستول / سايتوتيك (خطر إجهاض فوري - Category X)
    if (sciLower.contains('misoprostol') || medLower.contains('cytotec') || medLower.contains('سايتوتيك') || sciLower.contains('ميسوبروستول')) {
      return const PregnancySafetyInfo(
        isSafe: false,
        statusLabel: '⛔ ممنوع منعاً باتاً للحوامل (خطر إجهاض وتشوهات)',
        riskExplanation: 'يسبب انقباضات رحمية حادة وشديدة تؤدي إلى الإجهاض المباشر وموت الجنين أو تشوهات خلقية خطيرة.',
        safeAlternative: 'لعلاج قرحة وحموضة المعدة للحوامل: أوميبرازول (Omeprazole) أو جافيسكون (Gaviscon) أو فاموتيدين (Famotidine).',
        statusColor: Color(0xFFDC2626), // Deep Red
      );
    }

    // 2. المسكنات ومضادات الالتهاب غير الستيرويدية (NSAIDs: Diclofenac, Ibuprofen, Naproxen, Meloxicam, Ketoprofen, Celecoxib)
    if (sciLower.contains('diclofenac') || sciLower.contains('ibuprofen') || sciLower.contains('naproxen') ||
        sciLower.contains('meloxicam') || sciLower.contains('ketoprofen') || sciLower.contains('celecoxib') ||
        sciLower.contains('ديكلوفيناك') || sciLower.contains('ايبوبروفين') || sciLower.contains('نابروكسين') ||
        sciLower.contains('ميبورفين') || sciLower.contains('سيلكوكسيب') ||
        medLower.contains('voltaren') || medLower.contains('brufen') || medLower.contains('prof') ||
        medLower.contains('olphen') || medLower.contains('cataflam') || medLower.contains('فولتارين') ||
        medLower.contains('بروفين') || medLower.contains('كتافلام') || medLower.contains('رومافين')) {
      return const PregnancySafetyInfo(
        isSafe: false,
        statusLabel: '⚠️ ممنوع وغير آمن للحوامل (خاصة الثلث الثالث)',
        riskExplanation: 'قد يسبب انغلاقاً مبكراً للقناة الشريانية في قلب الجنين (Ductus Arteriosus)، ويقلل السائل السلوي ويؤدي للقصور الكلوي للجنين ومخاطر النزيف أثناء الولادة.',
        safeAlternative: 'البديل الآمن والمسكن المعتمد للحوامل: باراسيتامول (Paracetamol 500mg مثل Panadol الأزرق أو Adol أو Fevadol).',
        statusColor: Color(0xFFE11D48),
      );
    }

    // 3. أدوية الضغط الخطيرة على الجنين (ACE Inhibitors & ARBs & Statins)
    if (sciLower.contains('captopril') || sciLower.contains('enalapril') || sciLower.contains('lisinopril') ||
        sciLower.contains('losartan') || sciLower.contains('valsartan') || sciLower.contains('telmisartan') ||
        sciLower.contains('كابتوبريل') || sciLower.contains('لوسارتان') || sciLower.contains('فالسارتان') ||
        sciLower.contains('atorvastatin') || sciLower.contains('rosuvastatin') || sciLower.contains('simvastatin') ||
        sciLower.contains('اتورفاستاتين') || sciLower.contains('روزوفاستاتين') ||
        medLower.contains('lipitor') || medLower.contains('crestor') || medLower.contains('ليبيتور') || medLower.contains('كريستور')) {
      return const PregnancySafetyInfo(
        isSafe: false,
        statusLabel: '⛔ ممنوع قطعياً للحوامل (تشوهات جنينية Category X/D)',
        riskExplanation: 'يسبب تشوهات كلوية وعظمية ورئوية خطيرة للجنين وفشل نمو الأعضاء وقد يؤدي إلى الوفاة الجنينية.',
        safeAlternative: 'البديل الآمن لضغط الدم للحوامل: ميثيل دوبا (Methyldopa / Aldomet) أو لابيتالول (Labetalol) أو نيفيديبين (Nifedipine) بإشراف الطبيب.',
        statusColor: Color(0xFFDC2626),
      );
    }

    // 4. المضادات الحيوية الممنوعة للحوامل (Fluoroquinolones, Tetracyclines, Aminoglycosides)
    if (sciLower.contains('ciprofloxacin') || sciLower.contains('levofloxacin') || sciLower.contains('moxifloxacin') ||
        sciLower.contains('doxycycline') || sciLower.contains('tetracycline') || sciLower.contains('gentamicin') ||
        sciLower.contains('سيبروفلوكساسين') || sciLower.contains('ليفوفلوكساسين') || sciLower.contains('دوكسيسايكلين') ||
        sciLower.contains('تتراسيكلين') || sciLower.contains('جنتامايسين') ||
        medLower.contains('cipro') || medLower.contains('tavanic') || medLower.contains('doxy')) {
      return const PregnancySafetyInfo(
        isSafe: false,
        statusLabel: '⚠️ ممنوع للحوامل (تأثير على العظام والأسنان والغضاريف)',
        riskExplanation: 'التتراسيكلين يسبب تصبغ أسنان الجنين وتثبيط نمو العظام؛ والفلوروكينولونات تؤثر على نمو الغضاريف والمفاصل.',
        safeAlternative: 'البديل الآمن للعدوى البكتيرية للحوامل: أموكسيسيلين (Amoxicillin / Augmentin) أو سيفالوسبورين (Cefuroxime / Cefixime) أو أزيثرومايسين (Azithromycin).',
        statusColor: Color(0xFFEA580C),
      );
    }

    // 5. الوارفارين ومضادات التخثر الفموية الحديثة
    if (sciLower.contains('warfarin') || sciLower.contains('وارفارين') || medLower.contains('marevan') || medLower.contains('coumadin') ||
        sciLower.contains('rivaroxaban') || sciLower.contains('xarelto') || sciLower.contains('apixaban')) {
      return const PregnancySafetyInfo(
        isSafe: false,
        statusLabel: '⛔ ممنوع قطعياً للحوامل (متلازمة وارفارين الجنينية Category X)',
        riskExplanation: 'يعبر المشيمة ويسبب تشوهات وجهية وعظمية ونزيف دماغي حاد للجنين.',
        safeAlternative: 'البديل الآمن والوحيد المعتمد لمنع التجلط للحوامل: إينوكسابارين / هيبارين منخفض الوزن (Clexane / Enoxaparin حقن).',
        statusColor: Color(0xFFDC2626),
      );
    }

    // 6. أدوية البرد ومزيلات الاحتقان المركبة (Decongestants: Pseudoephedrine, Phenylephrine)
    if (sciLower.contains('pseudoephedrine') || sciLower.contains('phenylephrine') || sciLower.contains('سودوإيفيدرين') ||
        medLower.contains('congestal') || medLower.contains('comtrex') || medLower.contains('fludrex') ||
        medLower.contains('1,2,3') || medLower.contains('cold & flu') || medLower.contains('كلد اند فلو') ||
        medLower.contains('فلوتاب') || medLower.contains('كونجستال') || medLower.contains('كومتركس')) {
      return const PregnancySafetyInfo(
        isSafe: false,
        statusLabel: '⚠️ غير آمن في الحمل (تضييق الأوعية المشيمية)',
        riskExplanation: 'مزيلات الاحتقان قد تضيق الأوعية الدموية الرحمية وتقلل تدفق الدم والغذاء إلى الجنين خاصة في الأشهر الأولى.',
        safeAlternative: 'البديل الآمن لأعراض الزكام للحوامل: بنادول أزرق (Paracetamol) + بخاخ ماء بحر ملحي معقم (Saline Nasal Spray) + فيتامين C.',
        statusColor: Color(0xFFEA580C),
      );
    }

    // 7. الأدوية الآمنة والمصرحة للحوامل (Safe Pregnancy Choices)
    if (sciLower.contains('paracetamol') || sciLower.contains('باراسيتامول') || sciLower.contains('acetaminophen') ||
        medLower.contains('panadol') || medLower.contains('adol') || medLower.contains('fevadol') || medLower.contains('امول') || medLower.contains('ادول') ||
        sciLower.contains('amoxicillin') || sciLower.contains('اموكسيسيلين') || sciLower.contains('augmentin') || sciLower.contains('اوجمنتين') ||
        sciLower.contains('cef') || sciLower.contains('سيف') || sciLower.contains('azithromycin') || sciLower.contains('ازيثرومايسين') ||
        sciLower.contains('loratadine') || sciLower.contains('لوراتادين') || sciLower.contains('cetirizine') || sciLower.contains('سيتريزين') ||
        sciLower.contains('omeprazole') || sciLower.contains('اوميبرازول') || medLower.contains('gaviscon') || medLower.contains('جافيسكون') ||
        sciLower.contains('folic') || sciLower.contains('فوليك') || catLower.contains('vitamin') || catLower.contains('فيتامين')) {
      return const PregnancySafetyInfo(
        isSafe: true,
        statusLabel: '✅ مسموح وآمن للحوامل (وفق الجرعات الموصوفة)',
        riskExplanation: 'هذا الدواء يُعد من الخيارات الآمنة والمصرحة سريرياً للحوامل وفق توجيهات منظمة الصحة العالمية وهيئة الغذاء والدواء.',
        safeAlternative: 'الدواء آمن ولا يتطلب استبدالاً عند تناوله بالجرعات العلاجية المقررة.',
        statusColor: Color(0xFF16A34A), // Green
      );
    }

    // الحالة العامة الافتراضية
    return const PregnancySafetyInfo(
      isSafe: true,
      statusLabel: 'ℹ️ يُستخدم بحذر وتحت إشراف الطبيب المختص',
      riskExplanation: 'يُفضل دائماً مراجعة الطبيب المعالج أو الصيدلي السريري قبل تناول أي علاج دوائي أثناء فترة الحمل أو التخطيط له.',
      safeAlternative: 'استشارة الطبيب لاختيار البديل الأكثر أماناً وفق الحالة الصحية ومدة الحمل.',
      statusColor: Color(0xFF0284C7),
    );
  }

  /// تحليل مأمونية الدواء لمرضى القلب والضغط وتحديد البديل الآمن
  static CardiacSafetyInfo getCardiacSafety({
    required String medicineName,
    String? scientificName,
    String? categoryName,
  }) {
    final medLower = medicineName.toLowerCase();
    final sciLower = (scientificName ?? '').toLowerCase();

    // 1. أدوية البرد والجيوب الأنفية المحتوية على سودوإيفيدرين وفينيل إفرين (خطر ارتفاع الضغط والجلطة)
    if (sciLower.contains('pseudoephedrine') || sciLower.contains('phenylephrine') || sciLower.contains('سودوإيفيدرين') ||
        medLower.contains('congestal') || medLower.contains('comtrex') || medLower.contains('fludrex') ||
        medLower.contains('1,2,3') || medLower.contains('cold & flu') || medLower.contains('كلد اند فلو') ||
        medLower.contains('فلوتاب') || medLower.contains('كونجستال') || medLower.contains('كومتركس') ||
        medLower.contains('panadol cold') || medLower.contains('panadol extra') || medLower.contains('باندول اكسترا')) {
      return const CardiacSafetyInfo(
        isSafe: false,
        statusLabel: '⚠️ تحذير شديد لمرضى القلب والضغط المرتفع',
        riskExplanation: 'يحتوي على مواد قابضة للأوعية الدموية ومحفزات تسبب ارتفاعاً مفاجئاً في ضغط الدم، وتسارعاً في نبضات القلب (Tachycardia)، وخفقاناً شديداً.',
        safeAlternative: 'البديل الآمن لمرضى القلب والضغط: باراسيتامول منفرد بدون كافيين وسودوإيفيدرين (Panadol الأزرق أو Adol) + بخاخ أنف ملحي (Saline) + مضاد حساسية نقي (Loratadine/Claritin).',
        statusColor: Color(0xFFDC2626),
      );
    }

    // 2. مسكنات NSAIDs بجرعات متكررة (Diclofenac, Ibuprofen, Naproxen, Celecoxib, Meloxicam)
    if (sciLower.contains('diclofenac') || sciLower.contains('ibuprofen') || sciLower.contains('naproxen') ||
        sciLower.contains('meloxicam') || sciLower.contains('celecoxib') || sciLower.contains('ديكلوفيناك') ||
        sciLower.contains('ايبوبروفين') || sciLower.contains('نابروكسين') || sciLower.contains('سيلكوكسيب') ||
        medLower.contains('voltaren') || medLower.contains('brufen') || medLower.contains('cataflam') ||
        medLower.contains('olphen') || medLower.contains('فولتارين') || medLower.contains('بروفين')) {
      return const CardiacSafetyInfo(
        isSafe: false,
        statusLabel: '⚠️ تحذير لمرضى القلب وقصور الشرايين والضغط',
        riskExplanation: 'تسبب احتباس الصوديوم والماء بالجسم، مما يرفع ضغط الدم ويزيد العبء على عضلة القلب ويزيد خطر الحوادث الوعائية واحتشاء العضلة القلبية.',
        safeAlternative: 'البديل الآمن لتسكين الألم وخفض الحرارة لمرضى القلب: باراسيتامول (Paracetamol 500-1000mg) بجرعات علاجية منتظمة.',
        statusColor: Color(0xFFEA580C),
      );
    }

    // 3. أدوية الفلوروكينولونات (استطالة فترة QT واضطراب النبض)
    if (sciLower.contains('moxifloxacin') || sciLower.contains('ciprofloxacin') || sciLower.contains('levofloxacin') ||
        sciLower.contains('سيبروفلوكساسين') || sciLower.contains('ليفوفلوكساسين') || sciLower.contains('موكسيفلوكساسين')) {
      return const CardiacSafetyInfo(
        isSafe: false,
        statusLabel: '⚠️ تحذير لمرضى اضطراب نبضات القلب (QT Prolongation)',
        riskExplanation: 'قد تسبب استطالة الفترة الكهربائية للقلب (QT Interval) واضطرابات خطيرة في النظم القلبي لدى المرضى المعرضين لمشاكل القلب.',
        safeAlternative: 'البديل الآمن للعدوى البكتيرية لمرضى اضطراب النبض: مجموعة البنسلينات أو السيفالوسبورينات (Amoxicillin / Cefuroxime) بعد مراجعة الطبيب.',
        statusColor: Color(0xFFD97706),
      );
    }

    // 4. أدوية القلب وضغط الدم والوقاية الوعائية (موصوفة ومعتمدة لمرضى القلب)
    if (sciLower.contains('amlodipine') || sciLower.contains('losartan') || sciLower.contains('valsartan') ||
        sciLower.contains('bisoprolol') || sciLower.contains('metoprolol') || sciLower.contains('atenolol') ||
        sciLower.contains('atorvastatin') || sciLower.contains('aspirin') || sciLower.contains('clopidogrel') ||
        sciLower.contains('كونكور') || medLower.contains('concor') || medLower.contains('plavix') || medLower.contains('lipitor')) {
      return const CardiacSafetyInfo(
        isSafe: true,
        statusLabel: '✅ دواء مخصص لعلاج وضبط القلب والضغط الشرياني',
        riskExplanation: 'هذا الدواء يُعد من خطوط العلاج الأساسية لحماية القلب والشرايين والوقاية من الجلطات وتنظيم الضغط.',
        safeAlternative: 'الالتزام بالعلاج في نفس الموعد يومياً وعدم إيقافه فجأة دون استشارة الطبيب المختص.',
        statusColor: Color(0xFF16A34A),
      );
    }

    // 5. الأدوية العامة الآمنة لمرضى القلب
    if (sciLower.contains('paracetamol') || sciLower.contains('باراسيتامول') ||
        sciLower.contains('loratadine') || sciLower.contains('سيتريزين') || sciLower.contains('cetirizine') ||
        sciLower.contains('omeprazole') || sciLower.contains('amoxicillin')) {
      return const CardiacSafetyInfo(
        isSafe: true,
        statusLabel: '✅ آمن ومناسب لمرضى القلب والضغط الشرياني',
        riskExplanation: 'لا يؤثر سلباً على ضغط الدم أو ضربات القلب ولا يسبب تضيقاً وعائياً عند استخدامه بالجرعات الصحيحة.',
        safeAlternative: 'الدواء آمن تماماً ولا يتطلب استبدالاً.',
        statusColor: Color(0xFF16A34A),
      );
    }

    // الحالة العامة
    return const CardiacSafetyInfo(
      isSafe: true,
      statusLabel: 'ℹ️ آمن عموماً مع مراعاة الجرعات الموصوفة',
      riskExplanation: 'لا توجد موانع استخدام قلبية مباشرة مسجلة لهذا المركب بالجرعات المعتادة.',
      safeAlternative: 'في حال وجود أمراض قلبية مزمنة، يُنصح بالمتابعة الدورية مع الطبيب المعالج.',
      statusColor: Color(0xFF0284C7),
    );
  }

  /// استخراج موانع الاستعمال العامة الإضافية (الكلى، الكبد، الربو، وقرحة المعدة)
  static GeneralContraindicationsInfo getGeneralContraindications({
    required String medicineName,
    String? scientificName,
    String? categoryName,
  }) {
    final sciLower = (scientificName ?? '').toLowerCase();
    final medLower = medicineName.toLowerCase();
    final List<String> warnings = [];

    // قرحة المعدة
    if (sciLower.contains('diclofenac') || sciLower.contains('ibuprofen') || sciLower.contains('aspirin') ||
        sciLower.contains('naproxen') || sciLower.contains('ketoprofen') || medLower.contains('voltaren') || medLower.contains('brufen')) {
      warnings.add('⚠️ ممنوع لمرضى قرحة المعدة والنزيف الهضمي النشط.');
      warnings.add('⚠️ يُحذر استخدامه لمرضى الربو القصبي وحساسية الصدر (خطر تضيق القصبات).');
      warnings.add('⚠️ يُستخدم بحذر شديد لمرضى القصور الكلوي المتقدم.');
    }

    // مرضى الكبد
    if (sciLower.contains('paracetamol') || medLower.contains('panadol')) {
      warnings.add('⚠️ يجب عدم تجاوز 4 جرامات يومياً لتجنب السمية الكبدية، ويُحظر للمرضى المصابين بتليف أو قصور كبدي حاد.');
    }

    // الأطفال دون سن معينة
    if (sciLower.contains('aspirin') || medLower.contains('aspirin') || sciLower.contains('اسبرين')) {
      warnings.add('⛔ يمنع منعاً باتاً إعطاء الأسبرين للأطفال والمراهقين أثناء العدوى الفيروسية لتجنب متلازمة راي (Reye Syndrome) الخطيرة.');
    }

    if (sciLower.contains('ciprofloxacin') || sciLower.contains('levofloxacin')) {
      warnings.add('⚠️ غير موصى به للأطفال والمراهقين تحت 18 سنة حفاظاً على نمو المفاصل والغضاريف.');
    }

    if (warnings.isEmpty) {
      warnings.add('✅ لا توجد تحذيرات حرجة خاصة مسجلة، يُصرف وفق الوصفة الطبية المعتمدة.');
    }

    return GeneralContraindicationsInfo(warnings: warnings);
  }

  /// استخراج معلومات الوصفة الطبية والجرعات بدقة للدواء
  static ClinicalPrescriptionInfo getPrescriptionDetails({
    required String medicineName,
    String? scientificName,
    String? categoryName,
    String? rawReserve1,
    String? formOrPack,
  }) {
    final medLower = medicineName.toLowerCase();
    final sciLower = (scientificName ?? '').toLowerCase();
    final catLower = (categoryName ?? '').toLowerCase();
    final formLower = (formOrPack ?? '').toLowerCase();
    final res1 = (rawReserve1 ?? '').trim();

    // 1. فحص المضادات الحيوية (Antibiotics)
    if (sciLower.contains('amoxicillin') || sciLower.contains('اموكسيسيلين') ||
        sciLower.contains('augmentin') || sciLower.contains('اوجمنتين') ||
        medLower.contains('amox') || medLower.contains('augm') || medLower.contains('curam') || medLower.contains('klavox')) {
      return const ClinicalPrescriptionInfo(
        indications: 'علاج العدوى البكتيرية في الجهاز التنفسي، الأذن الوسطى، الحلق، الجيوب الأنفية، المسالك البولية والجلد.',
        adultDosage: '500 ملجم إلى 1000 ملجم كل 8 إلى 12 ساعة (قرص مرتين إلى 3 مرات يومياً بعد الطعام) لمدة 5-7 أيام.',
        pediatricDosage: 'شراب معلق: 25-45 ملجم/كجم يومياً مقسمة على جرعتين أو 3 جرعات (مثال: ملعقة 5 مل كل 8-12 ساعة حسب وزن الطفل وعمره).',
        instructions: 'يؤخذ في بداية أو بعد الوجبة لتقليل اضطرابات المعدة. يجب إكمال كامل الكورس العلاجي حتى نهايته وعدم إيقافه عند الشعور بالتحسن.',
      );
    }

    if (sciLower.contains('azithromycin') || sciLower.contains('ازيثرومايسين') || sciLower.contains('ازيترومايسين') ||
        medLower.contains('zithro') || medLower.contains('azith')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مضاد حيوي واسع المجال لعدوى الجهاز التنفسي، اللوزتين، الجيوب الأنفية، النزلات الشعبية والجلد.',
        adultDosage: '500 ملجم مرة واحدة يومياً قبل الأكل بساعة أو بعده بساعتين لمدة 3 أيام متتالية (أو 500 ملجم في اليوم الأول ثم 250 ملجم يومياً لـ 4 أيام).',
        pediatricDosage: 'شراب معلق: 10 ملجم/كجم مرة واحدة يومياً لمدة 3 أيام (أو حسب وزن الطفل والجرعة المحددة من الصيدلي/الطبيب).',
        instructions: 'يؤخذ على معدة فارغة أو مع وجبة خفيفة مع كوب ماء كامل. يؤخذ في نفس الموعد ثابتاً كل 24 ساعة.',
      );
    }

    if (sciLower.contains('ceftriaxone') || sciLower.contains('سفترياكسون') || sciLower.contains('سيفوتاكسيم') ||
        sciLower.contains('cefuroxime') || sciLower.contains('سيفوروكسيم') || sciLower.contains('cefixime') ||
        sciLower.contains('سيفكسيم') || sciLower.contains('cephalexin') || sciLower.contains('سيفالكسين') ||
        medLower.contains('zinnat') || medLower.contains('suprax') || medLower.contains('keflex') || medLower.contains('زينكس')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مضاد حيوي من عائلة السيفالوسبورينات لعلاج الالتهابات البكتيرية الحادة، الصدر، والمسالك والعمليات.',
        adultDosage: 'حقن (فيال): 1 إلى 2 جم يومياً كجرعة واحدة أو مقسمة كل 12 ساعة عضل أو وريد بطيء. (أقراص زينات/سوبراكس: 250-500 ملجم كل 12 ساعة).',
        pediatricDosage: 'حقن: 50-75 ملجم/كجم يومياً مقسمة على جرعة أو جرعتين. (شراب سيفكسيم/سيفوروكسيم: 8-15 ملجم/كجم يومياً مقسمة كل 12 ساعة).',
        instructions: 'يُفضل عمل اختبار حساسية قبل أول جرعة حقن. يجب حل الحقنة بمحلول معقم ومناسب وإعطاؤها ببطء بعد الأكل.',
      );
    }

    if (sciLower.contains('moxifloxacin') || sciLower.contains('موكسيفلوكساسين') ||
        sciLower.contains('ciprofloxacin') || sciLower.contains('سيبروفلوكساسين') ||
        sciLower.contains('levofloxacin') || sciLower.contains('ليفوفلوكساسين') ||
        sciLower.contains('ofloxacin') || sciLower.contains('اوفلوكساسين') ||
        medLower.contains('cipro') || medLower.contains('tavanic')) {
      if (formLower.contains('eye') || formLower.contains('drops') || formLower.contains('قطر') || formLower.contains('عين') || medLower.contains('قطر') || medLower.contains('eye')) {
        return const ClinicalPrescriptionInfo(
          indications: 'علاج التهابات وملتحمة العين البكتيرية والتقرحات والعدوى السطحية للعين.',
          adultDosage: 'قطرة واحدة إلى قطرتين في العين المصابة 3 إلى 4 مرات يومياً (كل 6 إلى 8 ساعات) لمدة 5-7 أيام.',
          pediatricDosage: 'للأطفال فوق عمر سنة: قطرة واحدة في العين المصابة 3 مرات يومياً لمدة 5-7 أيام تحت إشراف طبي.',
          instructions: 'غسل اليدين جيداً قبل الاستعمال، تجنب ملامسة طرف القطارة للعين، نزع العدسات اللاصقة أثناء فترة العلاج.',
        );
      }
      return const ClinicalPrescriptionInfo(
        indications: 'علاج العدوى البكتيرية الشديدة للجهاز التنفسي، المسالك البولية المعقدة، والتهابات الجهاز الهضمي والأنسجة الرخوة.',
        adultDosage: '400-500 ملجم مرة إلى مرتين يومياً (كل 12-24 ساعة) حسب شدة الحالة وموضع العدوى.',
        pediatricDosage: 'غير موصى به عموماً للأطفال والمراهقين دون 18 عاماً إلا للضرورات السريرية القصوى وبإشراف طبي مباشر.',
        instructions: 'شرب كميات وافرة من السوائل والماء (2-3 لتر يومياً)، تجنب تناوله بالتزامن مع مضادات الحموضة أو مشتقات الحديد والكالسيوم.',
      );
    }

    if (sciLower.contains('metronidazole') || sciLower.contains('ميترونيدازول') || medLower.contains('flagyl') || medLower.contains('فلاجيل') || sciLower.contains('tinidazole') || sciLower.contains('تينيدازول')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مضاد للطفيليات والبكتيريا اللاهوائية، علاج الدوسنتاريا، الأميبا، الجيارديا، وعدوى الأسنان والمهبل والبطن.',
        adultDosage: '500 ملجم كل 8 ساعات (3 مرات يومياً) بعد الوجبات لمدة 5 إلى 10 أيام.',
        pediatricDosage: 'شراب معلق: 30-50 ملجم/كجم يومياً مقسمة على 3 جرعات بعد الأكل لمدة 5-7 أيام.',
        instructions: 'يؤخذ مع أو بعد الطعام لتجنب الغثيان. يمنع تناول أي مشروبات كحولية نهائياً أثناء فترة العلاج.',
      );
    }

    if (sciLower.contains('fluconazole') || sciLower.contains('فلوكونازول') || sciLower.contains('nystatin') || sciLower.contains('نيستاتين') || medLower.contains('diflucan') || medLower.contains('ديسفلوكان')) {
      return const ClinicalPrescriptionInfo(
        indications: 'علاج الالتهابات الفطرية الموضعية والداخلية، فطريات الفم واللسان، وعدوى المبيضات والجلد.',
        adultDosage: 'كبسولة 150 ملجم جرعة واحدة أسبوعياً أو 50 ملجم يومياً لمدة 7-14 يوماً حسب موضع الفطريات.',
        pediatricDosage: 'قطارة نيستاتين للفم: 1 مل بالفم 4 مرات يومياً بعد الرضاعة، أو فلوكونازول 3-6 ملجم/كجم يومياً بإشراف الطبيب.',
        instructions: 'تُبلع الكبسولة مع كوب ماء مع أو بدون طعام. في فطريات الفم يجب إبقاء الشراب/النقط في الفم لأطول فترة قبل البلع.',
      );
    }

    if (sciLower.contains('albendazole') || sciLower.contains('البندازول') || sciLower.contains('mebendazole') || sciLower.contains('ميبندازول') || medLower.contains('vermox') || medLower.contains('bendax') || medLower.contains('فيرموكس')) {
      return const ClinicalPrescriptionInfo(
        indications: 'طارد وقاتل للديدان المعوية والطفيليات (الديدان الدبوسية، الأسكارس، الشريطية، والخطافية).',
        adultDosage: 'قرص واحد 400 ملجم جرعة وحيدة تُكرر بعد أسبوعين (أو 100 ملجم مرتين يومياً لمدة 3 أيام للديدان المعقدة).',
        pediatricDosage: 'للأطفال فوق سنتين: 400 ملجم جرعة وحيدة (أو 10 مل شراب 200ملجم/5مل) وتكرر بعد 14 يوماً.',
        instructions: 'تُمضغ الأقراص جيداً أو تُبلع مع وجبة غنية بالدهون لزيادة الفعالية. يُفضل علاج جميع أفراد الأسرة في نفس التوقيت.',
      );
    }

    // 2. فحص المسكنات وخافضات الحرارة (Analgesics / NSAIDs / Antipyretics)
    if (sciLower.contains('paracetamol') || sciLower.contains('باراسيتامول') || sciLower.contains('acetaminophen') ||
        medLower.contains('panadol') || medLower.contains('adol') || medLower.contains('amol') || medLower.contains('باندول') || medLower.contains('امول') || medLower.contains('ادول') || medLower.contains('fevadol') || medLower.contains('cetal')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مسكن آمن للآلام الخفيفة والمتوسطة، وخافض فعال للحرارة وحالات الصداع، آلام الأسنان، نزلات البرد، والحمى.',
        adultDosage: '500 ملجم إلى 1000 ملجم (قرص إلى قرصين) كل 4 إلى 6 ساعات عند اللزوم (الحد الأقصى 4000 ملجم / 8 أقراص يومياً).',
        pediatricDosage: 'شراب / نقط / تحاميل: 10 إلى 15 ملجم/كجم لكل جرعة كل 4-6 ساعات عند اللزوم (الحد الأقصى 4-5 جرعات في 24 ساعة).',
        instructions: 'يمكن تناوله قبل أو بعد الأكل. يجب عدم الجمع بينه وبين أدوية برد أخرى تحتوي على نفس المادة لتجنب زيادة الجرعة.',
      );
    }

    if (sciLower.contains('ibuprofen') || sciLower.contains('ايبوبروفين') || medLower.contains('prof') || medLower.contains('brufen') || medLower.contains('بروفين')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مسكن للآلام ومضاد للالتهاب وخافض للحرارة في حالات الصداع، آلام المفاصل والأسنان وعسر الطمث والتهاب الحلق.',
        adultDosage: '400 ملجم كل 6 إلى 8 ساعات بعد الأكل مباشرة عند اللزوم (الحد الأقصى 1200 - 2400 ملجم يومياً).',
        pediatricDosage: 'شراب للأطفال: 5 إلى 10 ملجم/كجم كل 6-8 ساعات بعد الرضاعة أو الطعام (لا يُعطى للرضع أقل من 3 أشهر أو أقل من 5 كجم).',
        instructions: 'يؤخذ دائماً بعد وجبة طعام كاملة مع كأس ماء لحماية بطانة المعدة من التهيج.',
      );
    }

    if (sciLower.contains('diclofenac') || sciLower.contains('ديكلوفيناك') || medLower.contains('voltaren') || medLower.contains('olphen') || medLower.contains('فولتارين') || medLower.contains('cataflam') || medLower.contains('كتافلام')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مضاد التهاب ومسكن قوي لآلام العظام والمفاصل، الروماتيزم، آلام العمود الفقري، والمغص الكلوي وما بعد الجراحة.',
        adultDosage: '50 ملجم مرتين إلى 3 مرات يومياً بعد الطعام، أو حقنة عضلية 75 ملجم مرة يومياً عند اللزوم.',
        pediatricDosage: 'تحاميل أطفال (12.5 أو 25 ملجم): 0.5-2 ملجم/كجم يومياً مقسمة للأطفال فوق سنة واحدة فقط بإشراف طبي.',
        instructions: 'يؤخذ بعد الوجبات مباشرة. يُحذر استخدامه لمرضى قرحة المعدة النشطة أو القصور الكلوي الحاد دون استشارة الطبيب.',
      );
    }

    // 3. أدوية المغص والتقلصات والجهاز الهضمي (Antispasmodics & Antiemetics & PPIs)
    if (sciLower.contains('hyoscine') || sciLower.contains('buscopan') || sciLower.contains('بوسكوبان') ||
        sciLower.contains('drotaverine') || sciLower.contains('mebeverine') || sciLower.contains('دوسباتالين') ||
        medLower.contains('duspatal') || medLower.contains('coloverin') || medLower.contains('spasmomen') || medLower.contains('سبازمومين')) {
      return const ClinicalPrescriptionInfo(
        indications: 'تسكين وعلاج تقلصات ومغص البطن، القولون العصبي، المغص الكلوي والمراري وتقلصات الدورة الشهرية.',
        adultDosage: '1-2 قرص (10-20 ملجم) 3 مرات يومياً قبل الوجبات بـ 20 دقيقة عند اللزوم.',
        pediatricDosage: 'للأطفال من 6 إلى 12 سنة: قرص واحد (10 ملجم) مرتين إلى 3 مرات يومياً أو شراب حسب وزن الطفل بإشراف الطبيب.',
        instructions: 'يُفضل تناوله قبل الوجبات بنصف ساعة مع نصف كوب ماء لتهدئة حركة وتقلصات الأمعاء.',
      );
    }

    if (sciLower.contains('ondansetron') || sciLower.contains('اوندانسيترون') || sciLower.contains('domperidone') || sciLower.contains('دومبيريدون') ||
        sciLower.contains('metoclopramide') || medLower.contains('zofran') || medLower.contains('motilium') || medLower.contains('موتيليوم') || medLower.contains('برمبران')) {
      return const ClinicalPrescriptionInfo(
        indications: 'الوقاية والعلاج من الغثيان والقيء، عسر الهضم والارتجاع، وتهدئة اضطرابات المعدة الناتجة عن العدوى أو العلاجات.',
        adultDosage: 'أقراص 4-8 ملجم أو 10 ملجم 2 إلى 3 مرات يومياً قبل الأكل بـ 15-30 دقيقة.',
        pediatricDosage: 'شراب / نقط: 0.15 ملجم/كجم (للأوندانسيترون) أو 0.25 ملجم/كجم (للدومبيريدون) قبل الوجبة بـ 15 دقيقة.',
        instructions: 'يؤخذ دائماً قبل تناول الطعام بـ 15 إلى 30 دقيقة حتى يعطي مفعوله المضاد للقيء والغثيان بكفاءة.',
      );
    }

    if (sciLower.contains('omeprazole') || sciLower.contains('اوميبرازول') ||
        sciLower.contains('esomeprazole') || sciLower.contains('ايزوميبرازول') ||
        sciLower.contains('pantoprazole') || sciLower.contains('بانتوبرازول') ||
        sciLower.contains('lansoprazole') || sciLower.contains('لانزوبرازول') ||
        medLower.contains('gasec') || medLower.contains('nexium') || medLower.contains('لوماك') || medLower.contains('اوميز')) {
      return const ClinicalPrescriptionInfo(
        indications: 'علاج قرحة المعدة والاثني عشر، ارتجاع المريء، حموضة وحرقة المعدة، والوقاية من قرحة المسكنات.',
        adultDosage: '20 إلى 40 ملجم كبسولة واحدة يومياً في الصباح قبل الإفطار بنصف ساعة لمدة 4 إلى 8 أسابيع.',
        pediatricDosage: 'للأطفال فوق عمر سنة: 10-20 ملجم يومياً صباحاً قبل الأكل بإشراف الطبيب المختص لحالات الارتجاع الشديد.',
        instructions: 'تُبتلع الكبسولة كاملة دون مضغ أو سحق مع نصف كوب ماء قبل أول وجبة في الصباح بـ 30-60 دقيقة.',
      );
    }

    if (sciLower.contains('antacid') || sciLower.contains('aluminium') || sciLower.contains('magnesium') || sciLower.contains('مالوكس') || medLower.contains('maalox') || medLower.contains('gaviscon') || medLower.contains('جافيسكون')) {
      return const ClinicalPrescriptionInfo(
        indications: 'تخفيف فوري لحرقة المعدة، عسر الهضم الحمضي، وارتجاع أحماض المعدة إلى المريء.',
        adultDosage: '1-2 ملعقة طعام كبيرة (10-20 مل) أو 1-2 قرص مضغ بعد الوجبات بساعة وعند النوم (3-4 مرات يومياً).',
        pediatricDosage: 'للأطفال فوق 6 سنوات: ملعقة صغيرة (5 مل) بعد الوجبات وعند النوم عند اللزوم.',
        instructions: 'يُرج الشراب جيداً قبل الاستعمال، أو تُمضغ الأقراص جيداً في الفم قبل البلع. يفصل ساعتين بينه وبين أي أدوية أخرى.',
      );
    }

    // 4. أدوية السعال والكحة ونزلات البرد (Cough, Cold & Respiratory)
    if (sciLower.contains('ambroxol') || sciLower.contains('امبروكسول') || sciLower.contains('bromhexine') || sciLower.contains('acetylcysteine') ||
        sciLower.contains('استيل سستايين') || medLower.contains('mucosolvan') || medLower.contains('bisolvon') || medLower.contains('ميوكوسولفان')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مذيب وطارد للبلغم والمخاط في حالات التهاب الشعب الهوائية، السعال الرطب، والتهابات القصبة الهوائية.',
        adultDosage: 'ملعقة كبيرة (10 مل) أو فوار 200-600 ملجم مرتين إلى 3 مرات يومياً بعد الطعام.',
        pediatricDosage: 'للأطفال (2-6 سنوات): 2.5 مل (نصف ملعقة صغيرة) مرتين يومياً، (6-12 سنة): 5 مل مرتين إلى 3 مرات يومياً.',
        instructions: 'شرب كميات وافرة من الماء والسوائل الدافئة يومياً للمساعدة في إذابة البلغم وتسهيل طرده من الرئتين.',
      );
    }

    if (sciLower.contains('butamirate') || sciLower.contains('بوتاميرات') || sciLower.contains('dextromethorphan') ||
        medLower.contains('sinecod') || medLower.contains('سينيكود') || medLower.contains('tussivan') || medLower.contains('توسيفان')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مهدئ ومثبط للسعال الجاف غير المصحوب ببلغم والناجم عن تهيج الحلق والقصبات الهوائية.',
        adultDosage: 'ملعقة كبيرة (15 مل) 3 مرات يومياً قبل الوجبات أو عند اللزوم.',
        pediatricDosage: 'للأطفال (3-6 سنوات): 5 مل 3 مرات يومياً، (6-12 سنة): 10 مل 3 مرات يومياً (نقط الرضع: 10-25 نقطة حسب العمر).',
        instructions: 'يؤخذ بالجرعات المحددة، ويُمنع استخدامه في حالات السعال الرطب المصحوب ببلغم كثيف حتى لا يحتبس الإفراز بالصدر.',
      );
    }

    if (sciLower.contains('cetirizine') || sciLower.contains('سيتريزين') ||
        sciLower.contains('loratadine') || sciLower.contains('لوراتادين') ||
        sciLower.contains('fexofenadine') || sciLower.contains('فيكسوفينادين') ||
        sciLower.contains('desloratadine') || sciLower.contains('ديسلوراتادين') ||
        medLower.contains('zyrtec') || medLower.contains('clarit') || medLower.contains('كلاريتين') || medLower.contains('زيرتك')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مضاد للحساسية والرشح، علاج حساسية الأنف الموسمية، العطاس، الحكة، حساسية الجلد، والارتيكاريا.',
        adultDosage: '10 ملجم (قرص واحد) مرة واحدة يومياً، يفضل مساءً قبل النوم.',
        pediatricDosage: 'للأطفال (2-6 سنوات): 2.5-5 ملجم يومياً (نصف ملعقة إلى ملعقة شراب)، للأطفال (6-12 سنة): 5-10 ملجم يومياً.',
        instructions: 'يؤخذ مع أو بدون طعام مع كأس ماء. قد يسبب نعاساً خفيفاً لبعض المرضى لذا يفضل تناوله قبل النوم.',
      );
    }

    if (sciLower.contains('pseudoephedrine') || sciLower.contains('chlorpheniramine') || medLower.contains('cold') || medLower.contains('flu') || medLower.contains('فلو') || medLower.contains('كونجستال') || medLower.contains('كومتركس') || medLower.contains('1,2,3')) {
      return const ClinicalPrescriptionInfo(
        indications: 'علاج أعراض نزلات البرد والإنفلونزا، احتقان وانسداد الأنف والجيوب الأنفية، الرشح، الصداع، وتكسير الجسم.',
        adultDosage: 'قرص واحد كل 6 إلى 8 ساعات بعد الأكل (الحد الأقصى 3 إلى 4 أقراص في 24 ساعة).',
        pediatricDosage: 'شراب أطفال: ملعقة 5 مل كل 8 ساعات للأطفال من 6-12 سنة (غير موصى به للأطفال دون 6 سنوات بدون استشارة الطبيب).',
        instructions: 'يؤخذ بعد الوجبات مع شرب سوائل دافئة. يحذر لمرضى الضغط المرتفع غير المنضبط أو تضخم البروستاتا.',
      );
    }

    // 5. القطرات والمستحضرات الموضعية (Drops & Topicals)
    if (formLower.contains('drop') || formLower.contains('قطر') || formLower.contains('eye') || formLower.contains('ear') || formLower.contains('عين') || formLower.contains('اذن')) {
      return const ClinicalPrescriptionInfo(
        indications: 'علاج التهابات واحتقان وإفرازات العين أو الأذن والتخفيف من الحكة والجفاف.',
        adultDosage: 'قطرة إلى قطرتين في العين/الأذن المصابة كل 6 إلى 8 ساعات يومياً حسب وصف الطبيب.',
        pediatricDosage: 'قطرة واحدة في العين/الأذن المصابة 2 إلى 3 مرات يومياً تحت إشراف طبي.',
        instructions: 'تطهير اليدين وتدفئة زجاجة قطرة الأذن قليلاً براحة اليد قبل التقطير لتجنب الدوخة. عدم ملامسة الفوهة لأي سطح.',
      );
    }

    if (formLower.contains('cream') || formLower.contains('ointment') || formLower.contains('gel') || formLower.contains('مرهم') || formLower.contains('كريم') || formLower.contains('جل')) {
      return const ClinicalPrescriptionInfo(
        indications: 'علاج موضعي للالتهابات الجلدية، الحكة، الحساسية، الجروح، التسلخات، أو تسكين الآلام العضلية.',
        adultDosage: 'طبقة رقيقة تُدهن بلطف على المنطقة المصابة بعد تنظيفها وتجفيفها من مرتين إلى 3 مرات يومياً.',
        pediatricDosage: 'طبقة رقيقة جداً مرة إلى مرتين يومياً على الجلد النظيف مع تجنب ملامسة العينين والأغشية المخاطية.',
        instructions: 'للاستخدام الخارجي فقط. غسل اليدين جيداً قبل وبعد الاستعمال. تجنب تغطية المنطقة المعالجة بضمادات محكمة إلا بتوجيه طبي.',
      );
    }

    // 6. الفيتامينات والمكملات (Vitamins & Supplements)
    if (catLower.contains('vitamin') || catLower.contains('فيتامين') || sciLower.contains('vitamin') || sciLower.contains('calcium') || sciLower.contains('iron') || sciLower.contains('حديد') || sciLower.contains('كالسيوم') || sciLower.contains('zinc') || sciLower.contains('زنك')) {
      return const ClinicalPrescriptionInfo(
        indications: 'مكمل غذائي لتعزيز المناعة، تقوية العظام والأعصاب، علاج الأنيميا ونقص الفيتامينات والمعادن بالجسم.',
        adultDosage: 'كبسولة أو قرص واحد يومياً بعد وجبة الإفطار أو الغداء مباشرة مع كأس كبير من الماء.',
        pediatricDosage: 'شراب / نقط أطفال: الجرعة اليومية الموصى بها (مثال: ملعقة صغيرة 5 مل يومياً أو 4-5 نقط للرضع).',
        instructions: 'يفضل تناوله في الصباح مع الوجبة. مكملات الحديد تؤخذ مع عصير برتقال لزيادة الامتصاص ويفصل بينها وبين الشاي والحليب ساعتين.',
      );
    }

    // 7. أدوية الضغط والسكر والأمراض المزمنة
    if (catLower.contains('cardio') || catLower.contains('قلب') || catLower.contains('ضغط') || sciLower.contains('amlodipine') || sciLower.contains('losartan') || sciLower.contains('metformin') || sciLower.contains('glimepiride') || sciLower.contains('bisoprolol')) {
      return const ClinicalPrescriptionInfo(
        indications: 'علاج وضبط الضغط الشرياني أو تنظيم مستويات السكر في الدم والوقاية من المضاعفات الوعائية والقلبية.',
        adultDosage: 'قرص واحد يومياً في موعد ثابت صباحاً أو حسب الجرعة الموصوفة من الطبيب المعالج.',
        pediatricDosage: 'علاج مخصص للبالغين فقط - لا يُصرف للأطفال إلا بوصفة استشاري مختص.',
        instructions: 'الالتزام التام بتناول الدواء في نفس التوقيت يومياً وعدم إيقافه فجأة دون مراجعة الطبيب، مع القياس الدوري للضغط والسكر.',
      );
    }

    // 8. الحالة العامة الذكية الافتراضية
    final indication = (res1.isNotEmpty && !res1.contains('علاج يحتوي على'))
        ? res1
        : 'علاج سريري دوائي معتمد للتركيبة الفعالة: ${scientificName ?? medicineName}، يُستخدم وفق التشخيص الطبي المعتمد.';

    return ClinicalPrescriptionInfo(
      indications: indication,
      adultDosage: 'الجرعة المعتادة للبالغين: قرص/كبسولة كل 8 إلى 12 ساعة بعد الطعام، أو حسب الوصفة الطبية المحددة للحالة.',
      pediatricDosage: 'الجرعة للأطفال: تُحسب وفقاً لوزن وعمر الطفل وتحت إشراف الصيدلي أو الطبيب المختص (يفضل الأشكال السائلة كالمعلق والنقط).',
      instructions: 'يُحفظ في مكان جاف وبارد بعيداً عن الرطوبة وحرارة الشمس المباشرة (أقل من 25-30 مئوية) وبعيداً عن متناول الأطفال. يُرجى الالتزام بالجرعات الموصوفة.',
    );
  }
}

