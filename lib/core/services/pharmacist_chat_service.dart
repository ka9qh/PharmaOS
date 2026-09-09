// محرك الذكاء الصيدلاني والطبي والسريري الشامل - PharmaOS
// يمتلك قاعدة معرفة طبية وصيدلانية سريرية واسعة تعمل محلياً وفورياً
// للأدوية، البدائل، الجرعات، الحمل، التفاعلات، والاستعلامات الإدارية.

import '../../features/medicines/domain/entities/medicines_entity.dart';
import '../../features/medicines/domain/repositories/medicines_repository.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';
import '../../features/reports/domain/repositories/reports_repository.dart';
import 'stock_alert_service.dart';
import 'local_analytics_service.dart';

class PharmacistChatService {
  final MedicinesRepository _medicinesRepository;
  final InventoryRepository _inventoryRepository;
  final StockAlertService _stockAlertService;
  final LocalAnalyticsService _analyticsService;
  final ReportsRepository _reportsRepository;

  PharmacistChatService(
    this._medicinesRepository,
    this._inventoryRepository,
    this._stockAlertService,
    this._analyticsService,
    this._reportsRepository,
  );

  bool _matchesAny(String text, List<String> keywords) =>
      keywords.any((k) => text.toLowerCase().contains(k.toLowerCase()));

  // المعجم السريري الموسع للأدوية والبدائل والجرعات
  static final Map<String, String> _clinicalKnowledge = {
    'بنادول': '''
💊 **باراسيتامول / بنادول (Paracetamol / Panadol):**
• **الاستخدام:** مسكن للآلام وخافض للحرارة.
• **الجرعة للبالغين:** 500 ملجم إلى 1000 ملجم كل 6-8 ساعات (الحد الأقصى 4 جرام/يوم).
• **الجرعة للأطفال:** 10-15 ملجم/كجم كل 6 ساعات.
• **أمان الحمل والرضاعة:** آمن تماماً (Category B) وهو الخيار الأول.
• **البدائل المتاحة:** بارامول، أدول، تايلينول، فيفادول، أومول، ريفانين.
• **تحذير:** تجنب الجرعات الزائدة لمرضى الكبد.
''',
    'باراسيتامول': '''
💊 **باراسيتامول (Paracetamol):**
• **الاستخدام:** تسكين الآلام وخفض الحرارة والصداع.
• **الجرعة:** 500 - 1000 ملجم كل 6 ساعات للبالغين.
• **الحمل:** آمن وموصى به للحوامل والمرضعات.
• **البدائل:** بنادول، أدول، فيفادول، بارامول، أمول، ريفانين.
''',
    'أوجمنتين': '''
💊 **أوجمنتين / كلافوكس (Amoxicillin + Clavulanic Acid):**
• **الاستخدام:** مضاد حيوي واسع المجال لالتهابات الجهاز التنفسي والمسالك والجلد.
• **الجرعة للبالغين:** 625 ملجم كل 8 ساعات، أو 1 جم (1000 ملجم) كل 12 ساعة بعد الأكل.
• **الجرعة للأطفال:** 25-45 ملجم/كجم/يوم مقسمة على جرعتين أو 3.
• **أمان الحمل:** آمن عموماً (Category B).
• **البدائل المتاحة:** كلافوكس، كلافودار، كلافاسيد، جلمنتين، ميجاموكس، أوجماكس.
• **نصيحة:** يؤخذ مع بداية الوجبة لتقليل اضطرابات المعدة.
''',
    'سيفكس': '''
💊 **سيفيكسيم / سيفكس (Cefixime 400mg):**
• **الاستخدام:** مضاد حيوي من الجيل الثالث للسيفالوسبورين لالتهابات المسالك، الصدر، والجيوب.
• **الجرعة:** 400 ملجم يومياً (كبسولة واحدة مرة واحدة أو 200 ملجم مرتين).
• **الحمل:** Category B (آمن باستشارة الطبيب).
• **البدائل:** وينكس، ماجناسيف، زيفيم، توبسيف، سيفيكسيم فارما.
''',
    'اوميبرازول': '''
💊 **أوميبرازول / لوسيك (Omeprazole):**
• **الاستخدام:** علاج قرحة المعدة، الحموضة، وارتجاع المريء (GERD).
• **الجرعة:** 20-40 ملجم يومياً على الريق قبل الإفطار بنصف ساعة.
• **الحمل:** Category C (يفضل رانتيدين أو فاموتيدين إن أمكن، أو بانتوبرازول).
• **البدائل:** رايسك، جاستروزول، لوسيك، أوميز، هيلسيك، بانتوبرازول (كونترولوك).
''',
    'بروفين': '''
💊 **إيبوبروفين / بروفين (Ibuprofen):**
• **الاستخدام:** مسكن ومضاد للالتهاب وخافض للحرارة لآلام المفاصل والأسنان.
• **الجرعة:** 400-600 ملجم بعد الأكل كل 8 ساعات.
• **الحمل:** ⚠️ ممنوع في الثلث الأخير من الحمل (Category D) لأنه قد يغلق القناة الشريانية للجنين.
• **البدائل:** ديكلوفيناك (فولتارين)، نابروكسين، باراسيتامول، كيتوبروفين (بروفينيد).
''',
    'فولتارين': '''
💊 **ديكلوفيناك الصوديوم / فولتارين (Diclofenac Sodium):**
• **الاستخدام:** مسكن قوي للآلام الروماتيزمية، المفاصل، المغص الكلوي والأسنان.
• **الجرعة:** 50 ملجم مرتين أو 3 مرات يومياً، أو حقنة 75 ملجم عضل عند اللزوم.
• **تحذيرات:** يؤخذ دائماً بعد الأكل مع الحذر لمرضى قرحة المعدة والضغط المرتفع والربو.
• **البدائل:** كلوفين، روفيناك، ديفيدو، أولفين، ديكلوماكس.
''',
    'سبروفلوكساسين': '''
💊 **سيبروفلوكساسين / سيبروباي (Ciprofloxacin):**
• **الاستخدام:** مضاد حيوي قوي لالتهابات المسالك البولية، النزلات المعوية، والتهابات العظام.
• **الجرعة:** 500 ملجم كل 12 ساعة قبل أو بعد الأكل بساعتين.
• **تحذيرات:** ⚠️ يمنع للأطفال تحت 18 سنة والحوامل لتأثيره على الغضاريف، وتجنب تناوله مع الحليب أو الكالسيوم مباشرة.
• **البدائل:** سيبروفار، سبروكين، سيبروكسين، أوفلوكساسين، ليفوفلوكساسين (تافانيك).
''',
    'أزيثرومايسين': '''
💊 **أزيثرومايسين / زيثروماكس (Azithromycin):**
• **الاستخدام:** مضاد حيوي لالتهابات الحلق، الشعب الهوائية، والجلد.
• **الجرعة المعتادة:** 500 ملجم مرة واحدة يومياً لمدة 3 أيام متتالية (أو 500 ملجم في اليوم الأول ثم 250 ملجم لمدة 4 أيام).
• **الحمل:** Category B (يعتبر من أكثر المضادات أماناً بعد البنسلينات).
• **البدائل:** زيثروماكس، زوماكس، أزيماك، آزال، أزيثروسين.
''',
    'ميتفورمين': '''
💊 **ميتفورمين / جلوكوفاج (Metformin / Glucophage):**
• **الاستخدام:** خافض لسكر الدم لمرضى السكري من النوع الثاني، وتكيس المبايض.
• **الجرعة:** 500-1000 ملجم مرتين يومياً مع أو بعد الوجبات الرئيسية.
• **البدائل:** جلوكوفاج، ديافاج، فورميت، فورمتين، أموفاج.
''',
    'أملوديبين': '''
💊 **أملوديبين / نورفاسك (Amlodipine):**
• **الاستخدام:** علاج ارتفاع ضغط الدم والذبحة الصدرية.
• **الجرعة:** 5-10 ملجم مرة واحدة يومياً صباحاً.
• **البدائل:** نورفاسك، أميلو، أمودال، فازوديب، لوديب.
''',
  };

  Future<String> answer(String rawQuestion) async {
    final q = rawQuestion.trim();
    if (q.isEmpty) return 'أهلاً بك! اكتب استفسارك الدوائي أو الإداري وسأجيبك فوراً 👨‍⚕️';

    // 1. الاستعلامات الإدارية والمبيعات والنواقص
    if (_matchesAny(q, ['ايش ناقص', 'ايش نحتاج', 'نواقص', 'ما ينقص', 'نواقص المخزون'])) {
      return _answerLowStock();
    }
    if (_matchesAny(q, ['منتهي', 'قارب', 'انتهاء الصلاحية', 'الصلاحية'])) {
      return _answerExpiring();
    }
    if (_matchesAny(q, ['مبيعات اليوم', 'كم بعنا', 'كم المبيعات', 'مبيعات النوبة', 'المبيعات'])) {
      return _answerTodaySales();
    }
    if (_matchesAny(q, ['الأرباح', 'كم الربح', 'صافي الربح', 'الارباح'])) {
      return _answerProfit();
    }
    if (_matchesAny(q, ['كم سعر', 'سعر ', 'بكم'])) {
      return _answerPrice(q);
    }
    if (_matchesAny(q, ['كم باقي', 'كم متبقي', 'كم عدد', 'الكمية المتوفرة'])) {
      return _answerQuantity(q);
    }
    if (_matchesAny(q, ['هل يوجد', 'هل عندنا', 'متوفر', 'موجود'])) {
      return _answerAvailability(q);
    }

    // 2. فحص المعجم السريري والبدائل والجرعات
    for (final entry in _clinicalKnowledge.entries) {
      if (q.contains(entry.key)) {
        return entry.value;
      }
    }

    // 3. أسئلة الحمل والرضاعة
    if (_matchesAny(q, ['حامل', 'الحمل', 'مرضع', 'الرضاعة'])) {
      return '''
🤰 **دليل أمان الأدوية للحوامل والمرضعات:**
• **المسكنات الآمنة:** باراسيتامول (بنادول الأزرق / أدول) هو الخيار الأكثر أماناً.
• **المضادات الحيوية الآمنة:** أموكسيسيلين، أوجمنتين، سيفالكسين، أزيثرومايسين.
• **أدوية الحموضة الآمنة:** رينيه، جافيسكون، فاموتيدين، أوميبرازول.
• **أدوية الحساسية الآمنة:** لوراتادين (كلاريتين)، سيتريزين (زيرتك).
• ⚠️ **أدوية ممنوعة للحامل:** إيبوبروفين (بروفين في الثلث الثالث)، سيبروفلوكساسين، تتراسيكلين، الرواكوتان، الوارفارين.
''';
    }

    // 4. أسئلة الصداع والمغص والحرارة الشائعة
    if (_matchesAny(q, ['صداع', 'الم راس', 'شقيقة'])) {
      return '''
🤕 **بروتوكول علاج الصداع في الصيدلية:**
1. **صداع التوتر العادي:** باراسيتامول 1000 ملجم أو بنادول إكسترا (مع كافيين).
2. **صداع مع التهاب أو أسنان:** بروفين 400 ملجم بعد الأكل أو كتافلام 50 ملجم.
3. **صداع نصفي (شقيقة):** بانادول مايجرين، أو ريزاتريبتان / سوماتريبتان، مع تجنب المنبهات.
4. **نصيحة:** قياس ضغط الدم للتأكد من عدم ارتفاعه.
''';
    }

    if (_matchesAny(q, ['مغص', 'تقلصات', 'الم بطن'])) {
      return '''
🩺 **بروتوكول علاج المغص والتقلصات المعوية:**
1. **المغص العام والقولون:** بسكوبان (Hyoscine Butylbromide) قرص كل 8 ساعات، أو سبازموبان / دوسباتالين.
2. **مغص مع انتفاخ وغازات:** ديسفلاتيل (Simethicone) للمضغ بعد الأكل.
3. **المغص الكلوي الشديد:** حقنة فولتارين أو بروفينيد مع سبازموفين عضل.
''';
    }

    // 5. محاولة البحث عن أي دواء مذكور في السؤال داخل قاعدة البيانات المحلية
    try {
      final allMeds = await _medicinesRepository.getAll();
      for (final med in allMeds) {
        final enMatch = med.nameEn != null && med.nameEn!.isNotEmpty && q.toLowerCase().contains(med.nameEn!.toLowerCase());
        if (q.contains(med.nameAr) || enMatch) {
          final qty = await _inventoryRepository.getAvailableQuantity(med.id);
          return '''
💊 **تفاصيل الدواء المطلوب:**
• **الاسم:** ${med.nameAr} ${med.nameEn != null ? '(${med.nameEn})' : ''}
• **السعر الحالي:** ${med.sellingPrice.toStringAsFixed(0)} ر.ي
• **الكمية المتوفرة بالمخزون:** $qty عبوة
• **الباركود:** ${med.barcode.isNotEmpty ? med.barcode : 'لا يوجد'}
''';
        }
      }
    } catch (_) {}

    return '''
👨‍⚕️ **المساعد الصيدلاني الذكي PharmaOS:**
أنا جاهز لمساعدتك في:
• **الاستفسارات الدوائية والبدائل:** (مثل: بدائل سيفكس، جرعة أوجمنتين، أدوية آمنة للحامل).
• **فحص المخزون والأسعار:** (مثل: كم سعر بنادول، هل يوجد أوجمنتين، كم باقي من بروفين).
• **النواقص والمبيعات:** (مثل: ايش ناقص بالمخزون، كم مبيعات اليوم، كم أرباح اليوم).
''';
  }

  Future<String> _answerLowStock() async {
    final lowStock = await _stockAlertService.getLowStockItems();
    if (lowStock.isEmpty) return '✓ ممتاز! جميع الأدوية متوفرة بكميات كافية ولا توجد نواقص حالياً.';
    final lines = lowStock.take(12).map((m) => '• ${m.medicineName}: متبقي ${m.totalQuantity} فقط (حد الطلب ${m.reorderLevel})');
    return '📋 قائمة النواقص التي تتطلب طلب شراء (${lowStock.length} صنف):\n${lines.join('\n')}';
  }

  Future<String> _answerExpiring() async {
    final items = await _analyticsService.getExpiringSoonBatches(daysThreshold: 60);
    if (items.isEmpty) return '✓ لا توجد أدوية منتهية أو قريبة الانتهاء خلال 60 يوماً.';
    final lines = items.take(10).map((b) => b.isAlreadyExpired
        ? '⚠️ ${b.medicineName}: منتهي بالفعل (الكمية ${b.quantity})'
        : '⏳ ${b.medicineName}: ينتهي خلال ${b.daysUntilExpiry} يوماً (الكمية ${b.quantity})');
    return '🚨 أدوية قريبة الانتهاء (${items.length}):\n${lines.join('\n')}';
  }

  Future<String> _answerTodaySales() async {
    final summary = await _reportsRepository.previewCurrentPeriod();
    return '📊 مبيعات الفترة الحالية: ${summary.totalSales.toStringAsFixed(0)} ر.ي';
  }

  Future<String> _answerProfit() async {
    final summary = await _reportsRepository.previewCurrentPeriod();
    return '💰 صافي الأرباح المحققة للفترة: ${summary.netProfit.toStringAsFixed(0)} ر.ي';
  }

  Future<String> _answerPrice(String q) async {
    final all = await _medicinesRepository.getAll();
    for (final m in all) {
      final enMatch = m.nameEn != null && m.nameEn!.isNotEmpty && q.toLowerCase().contains(m.nameEn!.toLowerCase());
      if (q.contains(m.nameAr) || enMatch) {
        return '💵 سعر "${m.nameAr}": ${m.sellingPrice.toStringAsFixed(0)} ر.ي (سعر الشراء: ${m.purchasePrice.toStringAsFixed(0)} ر.ي)';
      }
    }
    return 'لم أتعرف على اسم الدواء لتحديد سعره، يرجى كتابة اسم الدواء بوضوح.';
  }

  Future<String> _answerQuantity(String q) async {
    final all = await _medicinesRepository.getAll();
    for (final m in all) {
      final enMatch = m.nameEn != null && m.nameEn!.isNotEmpty && q.toLowerCase().contains(m.nameEn!.toLowerCase());
      if (q.contains(m.nameAr) || enMatch) {
        final qty = await _inventoryRepository.getAvailableQuantity(m.id);
        return '📦 الكمية المتوفرة من "${m.nameAr}": $qty عبوة في المخزون.';
      }
    }
    return 'يرجى كتابة اسم الدواء لمعرفة الكمية المتوفرة.';
  }

  Future<String> _answerAvailability(String q) async {
    final all = await _medicinesRepository.getAll();
    for (final m in all) {
      final enMatch = m.nameEn != null && m.nameEn!.isNotEmpty && q.toLowerCase().contains(m.nameEn!.toLowerCase());
      if (q.contains(m.nameAr) || enMatch) {
        final qty = await _inventoryRepository.getAvailableQuantity(m.id);
        if (qty > 0) {
          return '✅ نعم، "${m.nameAr}" متوفر بالمخزون ($qty عبوة) بسعر ${m.sellingPrice.toStringAsFixed(0)} ر.ي.';
        } else {
          return '❌ "${m.nameAr}" غير متوفر حالياً (الكمية = صفر) ويحتاج إلى طلب شراء.';
        }
      }
    }
    return 'لم أجد هذا الدواء في قاعدة البيانات، تأكد من صحة الاسم.';
  }
}
