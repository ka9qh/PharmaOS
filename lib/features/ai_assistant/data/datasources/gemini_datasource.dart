import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class GeminiDataSource {
  static const String _defaultApiKey = '';
  
  GenerativeModel? _model;
  ChatSession? _chat;
  final String _currentApiKey;
  bool _isInitialized = false;

  GeminiDataSource({String? apiKey}) 
      : _currentApiKey = (apiKey != null && apiKey.isNotEmpty) ? apiKey : _defaultApiKey {
    _init();
  }

  void _init() {
    try {
      if (!_currentApiKey.contains('DUMMY')) {
        _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: _currentApiKey,
          generationConfig: GenerationConfig(
            temperature: 0.3,
            maxOutputTokens: 1024,
          ),
        );
        _chat = _model?.startChat();
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('Gemini init error: ');
      _isInitialized = false;
    }
  }

  Future<String?> sendMessage(String message, {String? systemContext}) async {
    if (!_isInitialized || _chat == null) {
      return null;
    }

    try {
      String prompt = 'أنت صيدلي خبير ومساعد طبي ومالي ذكي مدمج داخل نظام الصيدلية المتقدم PharmaOS.\n'
          'التعليمات:\n'
          '1. أجب دائماً باللغة العربية بأسلوب دقيق، علمي، مختصر ومنظم (استخدم النقاط والقوائم عند الحاجة).\n'
          '2. إذا تم تزويدك بسياق أو أدوية من النظام، اعتمد عليها وأجب بدقة حول المخزون والأسعار والبدائل.\n'
          '3. عند ذكر البدائل، حدد المادة الفعالة والشكل الدوائي وفرق السعر إن وجد.\n'
          '4. عند التنبيه لتعارضات دوائية، اذكر درجة الخطورة والبديل الآمن.\n\n';

      if (systemContext != null && systemContext.isNotEmpty) {
        prompt += 'معلومات وسياق من النظام:\n$systemContext\n';
      }
      
      prompt += 'سؤال المستخدم:\n';

      final response = await _chat!
          .sendMessage(Content.text(prompt))
          .timeout(const Duration(seconds: 7));
          
      return response.text;
    } catch (e) {
      debugPrint('Gemini Cloud Error: ');
      return null; // Signals fallback to local engine
    }
  }
}
