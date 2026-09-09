// خدمة الذكاء الاصطناعي الشامل والمساعد الصيدلاني (Google Gemini AI + RAG) - PharmaOS
// يقوم بفحص السؤال، واستخراج بيانات الصيدلية محلياً من قاعدة البيانات عند الحاجة (أدوية، أسعار، كميات، عملاء، موردين، مبيعات)
// ثم إرسالها إلى Google Gemini لتقديم إجابة طبية وإدارية ذكية ودقيقة باللغة العربية دائماً.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../di/service_locator.dart';
import '../../features/medicines/domain/repositories/medicines_repository.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';
import '../../features/reports/domain/repositories/reports_repository.dart';
import '../../features/suppliers/domain/repositories/suppliers_repository.dart';
import '../../features/customers/domain/repositories/customers_repository.dart';
import 'stock_alert_service.dart';
import 'pharmacist_chat_service.dart';

class GeminiOnlineAiService {
  // المفتاح الافتراضي (يمكن تعيينه من شاشة الإعدادات)
  static const String _defaultApiKey = '';
  static const String _geminiApiKeyPref = 'gemini_api_key_v1';
  static const String _geminiModel = 'gemini-1.5-flash';

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
    final key = await getApiKey();
    return key.trim().isNotEmpty;
  }

  // استخراج البيانات ذات الصلة من قاعدة البيانات المحلية (RAG)
  static Future<String> _extractSystemContext(String question) async {
    final q = question.toLowerCase().trim();
    final buffer = StringBuffer();

    try {
      // 1. فحص استعلامات الأدوية والمخزون والأسعار
      if (q.contains('سعر') ||
          q.contains('بكم') ||
          q.contains('توفر') ||
          q.contains('متوفر') ||
          q.contains('موجود') ||
          q.contains('كمية') ||
          q.contains('باقي') ||
          q.contains('مخزون') ||
          q.contains('دواء') ||
          q.contains('علاج')) {
        final medRepo = sl<MedicinesRepository>();
        final invRepo = sl<InventoryRepository>();
        final allMeds = await medRepo.getAll();

        final matchedMeds = allMeds.where((m) {
          final arMatch = q.contains(m.nameAr.toLowerCase()) || m.nameAr.toLowerCase().contains(q);
          final enMatch = m.nameEn != null && m.nameEn!.isNotEmpty && q.contains(m.nameEn!.toLowerCase());
          return arMatch || enMatch;
        }).take(5).toList();

        if (matchedMeds.isNotEmpty) {
          buffer.writeln('📦 [بيانات الأدوية في مخزون الصيدلية]:');
          for (final med in matchedMeds) {
            final qty = await invRepo.getAvailableQuantity(med.id);
            buffer.writeln('• الاسم: ${med.nameAr} (${med.nameEn ?? ""}) | السعر: ${med.sellingPrice.toStringAsFixed(0)} ر.ي (شراء: ${med.purchasePrice.toStringAsFixed(0)} ر.ي) | المتوفر: $qty عبوة | الباركود: ${med.barcode} | الشركة: ${med.companyName ?? "عام"} | المورد: ${med.supplierName ?? "عام"}');
          }
        }
      }

      // 2. فحص استعلامات الموردين والشركات
      if (q.contains('مورد') || q.contains('شرك') || q.contains('وكيل') || q.contains('توزيع') || q.contains('رقم')) {
        try {
          final supRepo = sl<SuppliersRepository>();
          final suppliers = await supRepo.getAll();
          final matchedSuppliers = suppliers.where((s) {
            return q.contains(s.name.toLowerCase()) || (s.contactInfo != null && q.contains(s.contactInfo!.toLowerCase()));
          }).take(4).toList();

          if (matchedSuppliers.isNotEmpty) {
            buffer.writeln('🏢 [بيانات الموردين والشركات المسجلة بالنظام]:');
            for (final sup in matchedSuppliers) {
              buffer.writeln('• المورد: ${sup.name} | وسيلة التواصل: ${sup.contactInfo ?? "غير محدد"} | ملاحظات: ${sup.notes ?? "لا يوجد"}');
            }
          }
        } catch (_) {}
      }

      // 3. فحص استعلامات العملاء والديون
      if (q.contains('عميل') || q.contains('زبون') || q.contains('دين') || q.contains('حساب') || q.contains('آجل')) {
        try {
          final custRepo = sl<CustomersRepository>();
          final customers = await custRepo.getAll();
          final matchedCust = customers.where((c) {
            return q.contains(c.name.toLowerCase()) || (c.phone != null && q.contains(c.phone!));
          }).take(4).toList();

          if (matchedCust.isNotEmpty) {
            buffer.writeln('👤 [سجلات العملاء المسجلين بالنظام]:');
            for (final c in matchedCust) {
              buffer.writeln('• العميل: ${c.name} | الهاتف: ${c.phone ?? "لا يوجد"} | ملاحظات: ${c.notes ?? "لا يوجد"}');
            }
          }
        } catch (_) {}
      }

      // 4. فحص استعلامات النواقص وإغلاق اليومية والمبيعات
      if (q.contains('ناقص') || q.contains('نواقص') || q.contains('طلبية') || q.contains('نفد')) {
        try {
          final stockAlerts = sl<StockAlertService>();
          final lowItems = await stockAlerts.getLowStockItems();
          if (lowItems.isNotEmpty) {
            buffer.writeln('⚠️ [قائمة النواقص التي تتطلب طلب شراء (${lowItems.length} صنف)] :');
            for (final item in lowItems.take(8)) {
              buffer.writeln('• ${item.medicineName}: متبقي ${item.totalQuantity} فقط (حد الطلب: ${item.reorderLevel})');
            }
          }
        } catch (_) {}
      }

      if (q.contains('مبيعات اليوم') || q.contains('كم بعنا') || q.contains('ارباح') || q.contains('أرباح')) {
        try {
          final repRepo = sl<ReportsRepository>();
          final summary = await repRepo.previewCurrentPeriod();
          buffer.writeln('📊 [الملخص المالي للفترة الحالية]:');
          buffer.writeln('• إجمالي المبيعات: ${summary.totalSales.toStringAsFixed(0)} ر.ي');
          buffer.writeln('• صافي الأرباح: ${summary.netProfit.toStringAsFixed(0)} ر.ي');
        } catch (_) {}
      }

      // 5. فحص استعلامات التنبؤ بالمبيعات (Sales Forecasting)
      if (q.contains('تنبؤ') || q.contains('موسمي') || q.contains('توقع') || q.contains('شهر')) {
        try {
          final repRepo = sl<ReportsRepository>();
          final recent = await repRepo.listRecent();
          if (recent.isNotEmpty) {
            buffer.writeln('📈 [بيانات المبيعات التاريخية لغرض التنبؤ (آخر 30 فترة)] :');
            for (final record in recent.take(30)) {
              buffer.writeln('• تاريخ الإغلاق: ${record.createdAt.toIso8601String().split('T')[0]} | إجمالي المبيعات: ${record.totalSales} | الأرباح: ${record.netProfit}');
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error extracting context: $e');
    }

    return buffer.toString().trim();
  }

  // الاستدعاء الرئيسي للذكاء الاصطناعي
  static Future<String> askAi({
    required String prompt,
    String? imageBase64,
    String? customSystemInstruction,
    bool jsonMode = false,
  }) async {
    final apiKey = await getApiKey();

    // 1. استخراج بيانات النظام المرتبطة بالسؤال (فقط إذا لم يكن هناك تعليمات مخصصة)
    final systemContext = customSystemInstruction == null ? await _extractSystemContext(prompt) : '';

    // 2. صياغة التوجيه والمطالبة
    final systemInstruction = customSystemInstruction ?? '''
أنت "المساعد الصيدلاني الذكي الفائق" المدمج في نظام إدارة الصيدليات PharmaOS.
أنت خبير صيدلاني وطبي ونظامي.

قواعدك الصارمة:
1. الإجابة دائماً باللغة العربية الفصحى السليمة والواضحة فقط.
2. إذا كان السؤال عن بيانات الصيدلية (أدوية، أسعار، كميات، عملاء، موردين، مبيعات، نواقص)، اعتمد بدقة على البيانات المرفقة معك من قاعدة بيانات الصيدلية وأجب بأرقام وتفاصيل مؤكدة.
3. إذا كان السؤال طبياً أو سريرياً عاماً (مثل: جرعات الأدوية، التفاعلات الدوائية، بدائل الأدوية، أمان الحمل والرضاعة، بروتوكولات العلاج)، أجب كصيدلي سريري محترف وموثوق بنقاط واضحة ومنظمة.
4. إذا كان السؤال ترحيبياً أو عادياً (مثل: سلام، كيف حالك، مرحباً)، أجب بترحيب ودود وصيدلاني محترف.
5. نسّق الإجابة بنقاط وإيموجيات لتبدو فخمة وسريعة القراءة.
''';

    final fullPrompt = systemContext.isNotEmpty
        ? '''
[بيانات مستخرجة مباشرة من قاعدة بيانات الصيدلية الحالية]:
$systemContext

[سؤال المستخدم أو الصيدلي]:
$prompt
'''
        : prompt;

    // 3. إرسال الطلب إلى Google Gemini API
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$apiKey',
      );

      final generationConfig = <String, dynamic>{
        'temperature': 0.3,
        'maxOutputTokens': 2048,
      };

      if (jsonMode) {
        generationConfig['response_mime_type'] = 'application/json';
      }

      final requestBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '$systemInstruction\n\n$fullPrompt'},
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

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null && text.toString().trim().isNotEmpty) {
          return text.toString().trim();
        }
      } else {
        debugPrint('Gemini API status: ${response.statusCode}, body: ${response.body}');
      }

      // الانتقال الذكي للمحرك الصيدلاني المحلي في حال تعذر السحابة
      final chatService = sl<PharmacistChatService>();
      return await chatService.answer(prompt);
    } catch (e) {
      debugPrint('Gemini online exception: $e');
      final chatService = sl<PharmacistChatService>();
      return await chatService.answer(prompt);
    }
  }
}
