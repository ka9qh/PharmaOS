// خدمة الذكاء الاصطناعي الشامل والمساعد الصيدلاني (Google Gemini AI + RAG) - PharmaOS
// يقوم بفحص السؤال، واستخراج بيانات الصيدلية محلياً من قاعدة البيانات بدقة وشمول
// (أدوية، أسعار، كميات المخزون، بدائل متطابقة، نواقص، عملاء، موردين، مبيعات)
// ثم إرسالها إلى Google Gemini لتقديم إجابة طبية وإدارية ذكية ودقيقة باللغة العربية دائماً،
// مع توليد علامات أوامر تفاعلية قابلة للتنفيذ المباشر.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../di/service_locator.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';
import '../../features/inventory/domain/entities/inventory_entity.dart';
import '../../features/reports/domain/repositories/reports_repository.dart';
import '../../features/suppliers/domain/repositories/suppliers_repository.dart';
import '../../features/customers/domain/repositories/customers_repository.dart';
import 'pharmacist_chat_service.dart';
import 'ai_chat_history_service.dart';

class GeminiOnlineAiService {
  // المفاتيح الرسمية المعتمدة مع التبديل التلقائي عند الضغط (Failover & Rotation)
  static final List<String> _officialApiKeys = [
    utf8.decode(base64.decode('QVEuQWI4Uk42TFJHWXVkNGxXY3JlLXZjV1VJcmY0V2xYWkxkY1FwdG5NRTAtS0lyazBBNkE=')),
    utf8.decode(base64.decode('QVEuQWI4Uk42THRnVDEzZnpFUnZmWm5NeC15Z1ZqRXhSTU8xRW04UzBCWEM1UWxkU3B3aHc=')),
    utf8.decode(base64.decode('QVEuQWI4Uk42THJxODdOZ0hNTUs5WTlRTHRNVTZtd182MnF4UXJPSGVpVTA5Rm9jSTJBWGc=')),
    utf8.decode(base64.decode('QVEuQWI4Uk42SVYwVXdRcWJSOEFDMEh1WklZalhBaGVGTFJuLTFhdTFSTjJpVXlySENOZnc=')),
  ];
  static String get _defaultApiKey => _officialApiKeys.first;
  static const String _geminiApiKeyPref = 'gemini_api_key_v1';
  static const String _geminiModel = 'gemini-3.8-flash';
  static const List<String> _supportedModels = [_geminiModel, 'gemini-flash-latest', 'gemini-3.7-flash'];

  // استرجاع جميع المفاتيح المرشحة مع تقديم المفتاح المخصص إن وجد
  static Future<List<String>> getAllCandidateKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString(_geminiApiKeyPref)?.trim();
    final list = <String>[];
    if (customKey != null && customKey.isNotEmpty) {
      list.add(customKey);
    }
    for (final k in _officialApiKeys) {
      if (!list.contains(k)) {
        list.add(k);
      }
    }
    return list;
  }

  // استرجاع المفتاح المخصص أو الافتراضي
  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString(_geminiApiKeyPref);
    if (customKey != null && customKey.trim().isNotEmpty) {
      return customKey.trim();
    }
    return _defaultApiKey;
  }

  // حفظ مفتاح مخصص من الإعدادات
  static Future<void> setApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiApiKeyPref, apiKey.trim());
  }

  static Future<bool> hasApiKey() async {
    return _officialApiKeys.isNotEmpty;
  }

  /// تنظيف وتطبيع النص العربي للمطابقة الدقيقة
  static String _normalizeArabic(String text) {
    var s = text.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), ''); // إزالة التشكيل
    s = s.replaceAll(RegExp(r'[أإآ]'), 'ا');
    s = s.replaceAll('ة', 'ه');
    s = s.replaceAll('ى', 'ي');
    s = s.replaceAll(RegExp(r'[؟?!.,:;\-_/\\]'), ' ');
    return s;
  }

  /// استخراج سياق الصيدلية الشامل من قاعدة البيانات الحية (RAG المتطور)
  static Future<String> _extractSystemContext(String question) async {
    final cleanQ = _normalizeArabic(question);
    final buffer = StringBuffer();

    try {
      final invRepo = sl<InventoryRepository>();
      final stockOverview = await invRepo.getStockOverview();

      final inStockMeds = stockOverview.where((s) => s.totalQuantity > 0).toList();
      final lowStockMeds = stockOverview.where((s) => s.isLow).toList();

      // 1. ملخص الصيدلية اللحظي (يُرفق دائماً ليملك الذكاء أرقام الصيدلية الحقيقية)
      buffer.writeln('🏥 [بيانات صيدليتك الحقيقية المتصلة بالنظام]:');
      buffer.writeln('• إجمالي أصناف الأدوية المسجلة: ${stockOverview.length} صنف.');
      buffer.writeln('• أصناف متوفرة ولها كمية بالمخزون: ${inStockMeds.length} صنف.');
      buffer.writeln('• أصناف ناقصة بلغت حد إعادة الطلب: ${lowStockMeds.length} صنف.');

      // فحص الملخص المالي السريع
      try {
        final repRepo = sl<ReportsRepository>();
        final summary = await repRepo.previewCurrentPeriod();
        buffer.writeln('• مبيعات الوردية/اليوم الحالية: ${summary.totalSales.toStringAsFixed(0)} ر.ي (صافي الربح: ${summary.netProfit.toStringAsFixed(0)} ر.ي).');
      } catch (_) {}
      buffer.writeln();

      // 2. هل السؤال استعلام عام عن المخزون أو الأصناف المتوفرة؟
      final isGeneralStockQuery = cleanQ.contains('مخزون') ||
          cleanQ.contains('موجود') ||
          cleanQ.contains('متوفر') ||
          cleanQ.contains('جرد') ||
          cleanQ.contains('بضاع') ||
          cleanQ.contains('اصناف') ||
          cleanQ.contains('ادوي') ||
          cleanQ.contains('قائم') ||
          cleanQ.contains('عندك') ||
          cleanQ.contains('لديك') ||
          cleanQ.contains('صيدلي') ||
          cleanQ.contains('عرض') ||
          cleanQ.contains('كميه') ||
          cleanQ.contains('كلشي');

      // كلمات الاستبعاد الشائعة لاستخراج الكلمات الدالة
      final stopWords = {
        'في', 'من', 'على', 'إلى', 'هل', 'كم', 'ما', 'ماذا', 'هو', 'هي', 'يا',
        'دكتور', 'صيدلي', 'اريد', 'اعطني', 'بدي', 'عن', 'حق', 'شو', 'ايش', 'ابي',
        'ممكن', 'لو', 'سمحت', 'معي', 'عندي', 'هذا', 'هذه', 'ذلك', 'تلك', 'سعر',
        'بكم', 'موجود', 'متوفر', 'مخزون'
      };

      final tokens = cleanQ
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 3 && !stopWords.contains(t))
          .toList();

      // خريطة مطابقة الأعراض للأدوية والمجموعات
      final symptomKeywords = <String, List<String>>{
        'صداع': ['باراسيتامول', 'بنادول', 'ادول', 'ايبوبروفين', 'ديكلوفيناك', 'سولبادين', 'ريفانين'],
        'حمى': ['باراسيتامول', 'بنادول', 'ادول', 'بروفين', 'فيفادول', 'تايلينول'],
        'سعال': ['كوف', 'توسيكان', 'بروسبان', 'برومهيكسين', 'بلسم'],
        'كحه': ['كوف', 'توسيكان', 'بروسبان', 'برومهيكسين', 'بلسم'],
        'مغص': ['بسكوبان', 'سبازموبان', 'هيوسين'],
        'معد': ['اوميبرازول', 'فاموتيدين', 'جافيسكون', 'رانيدول', 'بانتوبرازول', 'نيكسيوم'],
        'حموض': ['اوميبرازول', 'فاموتيدين', 'جافيسكون', 'رانيدول', 'بانتوبرازول'],
        'ضغط': ['املوديبين', 'كونكور', 'كابوتين', 'لوزارتان', 'اتينولول'],
        'سكر': ['ميتفورمين', 'جلوكوفاج', 'دايمكرون', 'انسولين', 'جانوفيا'],
        'حساسي': ['سيتريزين', 'لوراتادين', 'فنستيل', 'زيرتك', 'كلاريتين'],
        'مضاد': ['اموكسيسيلين', 'اوجمنتين', 'كلافوكس', 'سيفكس', 'ازيثرومايسين', 'سبروفلوكساسين'],
        'التهاب': ['اموكسيسيلين', 'اوجمنتين', 'ايبوبروفين', 'ديكلوفيناك', 'سيفكس'],
      };

      for (final entry in symptomKeywords.entries) {
        if (cleanQ.contains(entry.key)) {
          tokens.addAll(entry.value.map(_normalizeArabic));
        }
      }

      // البحث عن الأدوية المطابقة
      final matchedStock = <StockSummary>[];
      for (final med in stockOverview) {
        final normAr = _normalizeArabic(med.medicineName);
        final normEn = _normalizeArabic(med.nameEn ?? '');
        final normSci = _normalizeArabic(med.nameScientific ?? '');
        final normCat = _normalizeArabic(med.categoryName ?? '');
        final normComp = _normalizeArabic(med.companyName ?? '');
        final normSup = _normalizeArabic(med.supplierName ?? '');

        bool isMatch = false;
        // فحص مطابقة العبارة بالكامل
        if (tokens.isEmpty && (normAr.contains(cleanQ) || cleanQ.contains(normAr))) {
          isMatch = true;
        } else {
          for (final token in tokens) {
            if (normAr.contains(token) ||
                normEn.contains(token) ||
                normSci.contains(token) ||
                normCat.contains(token) ||
                normComp.contains(token) ||
                normSup.contains(token)) {
              isMatch = true;
              break;
            }
          }
        }

        if (isMatch) {
          matchedStock.add(med);
        }
      }

      // 3. كتابة بيانات الأدوية المطابقة في السياق
      if (matchedStock.isNotEmpty) {
        buffer.writeln('🔍 [الأدوية المطابقة لاستفسارك من قاعدة بيانات الصيدلية (${matchedStock.length} دواء)]:');
        for (final m in matchedStock.take(15)) {
          final status = m.totalQuantity > 0
              ? 'متوفر: ${m.totalQuantity} ${m.unit}'
              : '⚠️ (غير متوفر حالياً - كمية 0)';
          buffer.writeln(
            '• [ID: ${m.medicineId}] ${m.medicineName} (${m.nameEn ?? ""}) | '
            'المادة الفعالة: ${m.nameScientific ?? "عام"} | '
            'الحالة: $status | '
            'سعر البيع: ${m.sellingPrice.toStringAsFixed(0)} ر.ي (شراء: ${m.purchasePrice.toStringAsFixed(0)} ر.ي) | '
            'الباركود: ${m.barcode} | الشركة: ${m.companyName ?? "عام"} | المورد: ${m.supplierName ?? "عام"}'
          );
        }
        buffer.writeln();

        // فحص البدائل المتوفرة للأصناف غير المتوفرة
        final outOfStock = matchedStock.where((m) => m.totalQuantity <= 0).toList();
        if (outOfStock.isNotEmpty) {
          buffer.writeln('💡 [بدائل متطابقة متوفرة بمخزون صيدليتك لنفس المادة الفعالة أو التصنيف]:');
          for (final o in outOfStock.take(3)) {
            final alternatives = inStockMeds.where((s) {
              if (s.medicineId == o.medicineId) return false;
              final sameSci = o.nameScientific != null &&
                  o.nameScientific!.isNotEmpty &&
                  s.nameScientific != null &&
                  _normalizeArabic(s.nameScientific!).contains(_normalizeArabic(o.nameScientific!));
              final sameCat = o.categoryId != null && s.categoryId == o.categoryId;
              return sameSci || sameCat;
            }).take(4).toList();

            if (alternatives.isNotEmpty) {
              buffer.writeln('بدائل متوفرة لدواء "${o.medicineName}":');
              for (final alt in alternatives) {
                buffer.writeln('  - [ID: ${alt.medicineId}] ${alt.medicineName} | المتوفر: ${alt.totalQuantity} ${alt.unit} | السعر: ${alt.sellingPrice.toStringAsFixed(0)} ر.ي');
              }
            }
          }
          buffer.writeln();
        }
      }

      // 4. إذا كان الاستعلام عاماً عن المخزون أو الأصناف ولم نجد عدداً كافياً من المطابقات المحددة:
      if (isGeneralStockQuery || matchedStock.length <= 2) {
        buffer.writeln('📦 [قائمة تفصيلية بأهم الأدوية المتوفرة حالياً في مخزون الصيدلية وأسعارها بالريال اليمني]:');
        for (final m in inStockMeds.take(25)) {
          buffer.writeln(
            '• [ID: ${m.medicineId}] ${m.medicineName} (${m.nameEn ?? ""}) | '
            'المادة الفعالة: ${m.nameScientific ?? "عام"} | '
            'الكمية: ${m.totalQuantity} ${m.unit} | '
            'سعر البيع: ${m.sellingPrice.toStringAsFixed(0)} ر.ي | '
            'التصنيف: ${m.categoryName ?? "عام"} | '
            'الشركة: ${m.companyName ?? "عام"}'
          );
        }
        buffer.writeln();
      }

      // 5. فحص استعلامات النواقص وإعادة الطلب
      if (cleanQ.contains('ناقص') ||
          cleanQ.contains('نواقص') ||
          cleanQ.contains('طلبي') ||
          cleanQ.contains('نفد') ||
          cleanQ.contains('شراء')) {
        if (lowStockMeds.isNotEmpty) {
          buffer.writeln('⚠️ [قائمة النواقص التي تتطلب طلب شراء (${lowStockMeds.length} صنف)]:');
          for (final item in lowStockMeds.take(15)) {
            buffer.writeln(
              '• [ID: ${item.medicineId}] ${item.medicineName}: متبقي ${item.totalQuantity} ${item.unit} فقط (حد إعادة الطلب: ${item.reorderLevel}) | سعر الشراء: ${item.purchasePrice.toStringAsFixed(0)} ر.ي | المورد: ${item.supplierName ?? "عام"}'
            );
          }
          buffer.writeln();
        }
      }

      // 6. فحص استعلامات الموردين والشركات
      if (cleanQ.contains('مورد') || cleanQ.contains('شرك') || cleanQ.contains('وكيل') || cleanQ.contains('توزيع')) {
        try {
          final supRepo = sl<SuppliersRepository>();
          final suppliers = await supRepo.getAll();
          if (suppliers.isNotEmpty) {
            buffer.writeln('🏢 [بيانات الموردين والشركات المسجلة بالنظام]:');
            for (final sup in suppliers.take(8)) {
              buffer.writeln('• المورد: ${sup.name} | وسيلة التواصل: ${sup.contactInfo ?? "غير محدد"} | ملاحظات: ${sup.notes ?? "لا يوجد"}');
            }
            buffer.writeln();
          }
        } catch (_) {}
      }

      // 7. فحص استعلامات العملاء والديون
      if (cleanQ.contains('عميل') || cleanQ.contains('زبون') || cleanQ.contains('دين') || cleanQ.contains('ديون') || cleanQ.contains('اجل') || cleanQ.contains('حساب')) {
        try {
          final custRepo = sl<CustomersRepository>();
          final customers = await custRepo.getAll();
          if (customers.isNotEmpty) {
            buffer.writeln('👤 [سجلات العملاء والديون المسجلة بالنظام]:');
            for (final c in customers.take(8)) {
              buffer.writeln('• العميل: ${c.name} | الهاتف: ${c.phone ?? "لا يوجد"} | ملاحظات: ${c.notes ?? "لا يوجد"}');
            }
            buffer.writeln();
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error extracting pharmacy context: $e');
    }

    return buffer.toString().trim();
  }

  // الاستدعاء الرئيسي للذكاء الاصطناعي (Google Gemini 3.8 Flash + RAG الشامل)
  static Future<String> askAi({
    required String prompt,
    List<AiChatMessage>? chatHistory,
    String? imageBase64,
    String? customSystemInstruction,
    bool jsonMode = false,
  }) async {
    // 1. استخراج بيانات النظام المرتبطة بالسؤال لحظياً من قاعدة البيانات
    final systemContext = customSystemInstruction == null ? await _extractSystemContext(prompt) : '';

    // 2. صياغة التوجيه والمطالبة (شخصية الطبيب والصيدلاني الاستشاري + تنفيذ الأوامر)
    final systemInstruction = customSystemInstruction ?? '''
أنت "المستشار الطبي والصيدلاني الذكي الفائق" المدمج في نظام إدارة الصيدليات المتقدم PharmaOS.
تجمع بخبرتك بين اختصاصين أساسيين:
1. طبيب استشاري: تقديم التشخيص الإرشادي، وشرح الحالات المرضية، ودواعي الاستعمال، والجرعات السليمة للبالغين والأطفال، وموانع الاستخدام وأمان الحمل والرضاعة.
2. صيدلي سريري محترف: خبير في علم الأدوية، والتركيبات العلمية والمواد الفعالة، والتداخلات الدوائية الخطرة (Drug-Drug Interactions)، والبدائل التجارية المتطابقة في المادة الفعالة والشكل والجرعة، مع حساب فروق الأسعار.

قواعد التعامل مع المخزون والبيانات:
1. أنت متصل مباشرة وبشكل حي بقاعدة بيانات الصيدلية الحالية والمخزون المرفق أدناه.
2. يُمنع منعاً باتاً القول 'لم يتم إرفاق أو ربط قائمة جرد المخزون' أو 'يرجى تزويدي ببيانات المخزون'؛ فقاعدة البيانات متصلة ومرفقة أمامك بالكامل.
3. أجب دائماً بثقة استناداً إلى هذه البيانات الدقيقة، واذكر أسماء الأدوية، والكميات المتوفرة، وأسعار البيع بالريال اليمني (ر.ي)، واقترح البدائل المتوفرة فعلياً في المخزون إذا كان الدواء المطلوب غير متوفر أو نفدت كميته.
4. الإجابة دائماً باللغة العربية الفصحى السليمة، الواضحة، والراقية جداً.
5. نسّق الإجابة بأسلوب منظم ومريح للعين مع استخدام العناوين البارزة، والنقاط، والإيموجيات المناسبة (💊، 🩺، ⚠️، 📋، 💡).

تنفيذ الأوامر (Action Execution):
عندما يطلب منك المستخدم أو الصيدلي تنفيذ أمر، أو عندما تجد دواءً مناسباً أو شاشة يمكن للصيدلي الانتقال إليها، قم بإدراج علامات الأوامر الذكية المناسبة في نهاية ردك ليقوم النظام بتحويلها لأزرار تفاعلية وتنفيذها فوراً:
• لإضافة دواء لسلة المبيعات:
  [ACTION:ADD_TO_CART|id=<medicine_id>|name=<medicine_name>|qty=<quantity>|price=<selling_price>]
• للتنقل بين الشاشات:
  [ACTION:NAVIGATE|screen=pos|title=فتح شاشة المبيعات (POS)]
  [ACTION:NAVIGATE|screen=inventory|title=فتح شاشة المخزون والجرد]
  [ACTION:NAVIGATE|screen=shortages|title=عرض النواقص ونواقص المخزون]
  [ACTION:NAVIGATE|screen=reports|title=التقارير المالية والمبيعات]
  [ACTION:NAVIGATE|screen=customers|title=سجلات العملاء والديون]
  [ACTION:NAVIGATE|screen=suppliers|title=سجلات الموردين والشركات]
  [ACTION:NAVIGATE|screen=purchases|title=فواتير المشتريات]
• لتجهيز طلبية شراء:
  [ACTION:CREATE_PURCHASE_ORDER|title=تجهيز طلبية شراء النواقص]
''';

    // 3. بناء سياق المحادثات السابقة إن وجد (Multi-turn Memory)
    final historyBuffer = StringBuffer();
    if (chatHistory != null && chatHistory.isNotEmpty) {
      final recent = chatHistory.length > 8 ? chatHistory.sublist(chatHistory.length - 8) : chatHistory;
      historyBuffer.writeln('--- [سجل المحادثة السابقة بينك وبين الصيدلي]: ---');
      for (final m in recent) {
        historyBuffer.writeln(m.isUser ? 'الصيدلي: ${m.text}' : 'المستشار: ${m.cleanDisplayText}');
      }
      historyBuffer.writeln('--- نهاية المحادثة السابقة ---\n');
    }

    final fullPrompt = StringBuffer();
    if (systemContext.isNotEmpty) {
      fullPrompt.writeln('[بيانات مستخرجة مباشرة ولحظياً من قاعدة بيانات صيدليتك الحالية]:');
      fullPrompt.writeln(systemContext);
      fullPrompt.writeln();
    }
    if (historyBuffer.isNotEmpty) {
      fullPrompt.writeln(historyBuffer.toString());
    }
    fullPrompt.writeln('[سؤال الصيدلي أو المستخدم الحالي]:');
    fullPrompt.writeln(prompt);

    // 4. محاولة الإرسال باستخدام المفاتيح المعتمدة بالتبادل التلقائي (Rotation & Failover)
    final candidateKeys = await getAllCandidateKeys();

    for (final apiKey in candidateKeys) {
      for (final model in _supportedModels) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          );

          final generationConfig = <String, dynamic>{
            'temperature': 0.3,
            'maxOutputTokens': 2500,
          };

          if (jsonMode) {
            generationConfig['response_mime_type'] = 'application/json';
          }

          final requestBody = {
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': '$systemInstruction\n\n${fullPrompt.toString()}'},
                  if (imageBase64 != null)
                    {
                      'inline_data': {
                        'mime_type': 'image/jpeg',
                        'data': imageBase64,
                      }
                    },
                ]
              }
            ],
            'generationConfig': generationConfig
          };

          final headers = {
            'Content-Type': 'application/json',
          };

          final response = await http
              .post(
                url,
                headers: headers,
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 25));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text != null && text.toString().trim().isNotEmpty) {
              return text.toString().trim();
            }
          } else {
            debugPrint('Gemini key (${apiKey.substring(0, 10)}...) with model $model returned ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Gemini exception on model $model: $e');
        }
      }
    }

    // الانتقال الذكي للمحرك الصيدلاني المحلي في حال تعذر السحابة أو انقطاع الإنترنت
    final chatService = sl<PharmacistChatService>();
    return await chatService.answer(prompt);
  }
}
