// خدمة إدارة وحفظ محادثات وأوامر الذكاء الاصطناعي - PharmaOS
// تضمن الاحتفاظ بسجل المحادثات، والذاكرة التراكمية، واستخراج وتنفيذ الأوامر الذكية.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiActionType {
  addToCart,
  navigate,
  createPurchaseOrder,
  unknown,
}

class AiAction {
  final AiActionType type;
  final String rawType;
  final int? medicineId;
  final String? medicineName;
  final int quantity;
  final double? price;
  final String? targetScreen;
  final String title;
  bool isExecuted;

  AiAction({
    required this.type,
    required this.rawType,
    this.medicineId,
    this.medicineName,
    this.quantity = 1,
    this.price,
    this.targetScreen,
    required this.title,
    this.isExecuted = false,
  });

  Map<String, dynamic> toJson() => {
        'type': rawType,
        'medicineId': medicineId,
        'medicineName': medicineName,
        'quantity': quantity,
        'price': price,
        'targetScreen': targetScreen,
        'title': title,
        'isExecuted': isExecuted,
      };

  factory AiAction.fromJson(Map<String, dynamic> json) {
    final raw = (json['type'] ?? '').toString();
    AiActionType aType = AiActionType.unknown;
    if (raw == 'ADD_TO_CART') aType = AiActionType.addToCart;
    if (raw == 'NAVIGATE') aType = AiActionType.navigate;
    if (raw == 'CREATE_PURCHASE_ORDER') aType = AiActionType.createPurchaseOrder;

    return AiAction(
      type: aType,
      rawType: raw,
      medicineId: json['medicineId'] is int ? json['medicineId'] : int.tryParse(json['medicineId']?.toString() ?? ''),
      medicineName: json['medicineName']?.toString(),
      quantity: json['quantity'] is int ? json['quantity'] : (int.tryParse(json['quantity']?.toString() ?? '1') ?? 1),
      price: json['price'] is num ? (json['price'] as num).toDouble() : double.tryParse(json['price']?.toString() ?? ''),
      targetScreen: json['targetScreen']?.toString(),
      title: json['title']?.toString() ?? 'إجراء ذكي',
      isExecuted: json['isExecuted'] == true,
    );
  }
}

class AiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AiAction> actions;

  AiChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    List<AiAction>? actions,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now(),
        actions = actions ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'actions': actions.map((a) => a.toJson()).toList(),
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    final actionsList = <AiAction>[];
    if (json['actions'] is List) {
      for (final a in (json['actions'] as List)) {
        if (a is Map<String, dynamic>) {
          actionsList.add(AiAction.fromJson(a));
        }
      }
    }

    return AiChatMessage(
      id: json['id']?.toString(),
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      actions: actionsList,
    );
  }

  // إرجاع النص بدون وسوم الأوامر لعرضه بشكل نظيف ومريح للقراءة
  String get cleanDisplayText {
    return text.replaceAll(RegExp(r'\[ACTION:[^\]]+\]'), '').trim();
  }
}

class AiChatHistoryService {
  static const String _prefKey = 'pharmaos_ai_chat_history_v2';
  static const int _maxSavedMessages = 150;

  static const String defaultWelcomeMessage =
      'مرحبًا بك دكتور 👨‍⚕️ أنا مستشارك الطبي والصيدلاني الذكي الفائق (Google Gemini 3.8 Flash).\n'
      'أنا مرتبط مباشرة بقاعدة بيانات الصيدلية، المخزون، الأسعار، والنواقص.\n'
      'يمكنك استشارتي طبياً وسريرياً، أو الاستعلام عن أي دواء ومخزونه وبدائله، أو إعطائي أوامر مباشرة مثل: إضافة دواء للسلة، أو فتح شاشات النظام.';

  /// تحميل جميع رسائل الدردشة المحفوظة
  static Future<List<AiChatMessage>> loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        return [
          AiChatMessage(
            text: defaultWelcomeMessage,
            isUser: false,
          )
        ];
      }

      final List decoded = jsonDecode(jsonStr);
      final list = decoded.map((item) => AiChatMessage.fromJson(item as Map<String, dynamic>)).toList();
      if (list.isEmpty) {
        return [
          AiChatMessage(
            text: defaultWelcomeMessage,
            isUser: false,
          )
        ];
      }
      return list;
    } catch (e) {
      debugPrint('Error loading AI chat history: $e');
      return [
        AiChatMessage(
          text: defaultWelcomeMessage,
          isUser: false,
        )
      ];
    }
  }

  /// حفظ قائمة الرسائل
  static Future<void> saveMessages(List<AiChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // الاحتفاظ بآخر _maxSavedMessages رسالة
      final trimmed = messages.length > _maxSavedMessages
          ? messages.sublist(messages.length - _maxSavedMessages)
          : messages;
      final jsonStr = jsonEncode(trimmed.map((m) => m.toJson()).toList());
      await prefs.setString(_prefKey, jsonStr);
    } catch (e) {
      debugPrint('Error saving AI chat history: $e');
    }
  }

  /// إضافة رسالة جديدة وحفظها
  static Future<void> appendMessage(AiChatMessage message) async {
    final current = await loadMessages();
    current.add(message);
    await saveMessages(current);
  }

  /// مسح سجل المحادثات والبدء من جديد
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugPrint('Error clearing AI chat history: $e');
    }
  }

  /// تحليل رد الذكاء الاصطناعي واستخراج علامات الأوامر الذكية
  /// مثل: [ACTION:ADD_TO_CART|id=12|name=بنادول|qty=2|price=1200]
  /// ومثل: [ACTION:NAVIGATE|screen=pos|title=شاشة المبيعات]
  /// ومثل: [ACTION:CREATE_PURCHASE_ORDER|title=تجهيز طلبية النواقص]
  static List<AiAction> parseActions(String text) {
    final actions = <AiAction>[];
    final regex = RegExp(r'\[ACTION:([^\|\]]+)(?:\|([^\]]+))?\]');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final actionTypeStr = match.group(1)?.trim().toUpperCase() ?? '';
      final paramsStr = match.group(2) ?? '';
      final params = <String, String>{};

      for (final part in paramsStr.split('|')) {
        final kv = part.split('=');
        if (kv.length == 2) {
          params[kv[0].trim().toLowerCase()] = kv[1].trim();
        }
      }

      if (actionTypeStr == 'ADD_TO_CART') {
        final id = int.tryParse(params['id'] ?? '');
        final name = params['name'] ?? 'دواء';
        final qty = int.tryParse(params['qty'] ?? '1') ?? 1;
        final price = double.tryParse(params['price'] ?? '0');
        actions.add(AiAction(
          type: AiActionType.addToCart,
          rawType: 'ADD_TO_CART',
          medicineId: id,
          medicineName: name,
          quantity: qty,
          price: price,
          title: '🛒 إضافة $name ($qty) لسلة المبيعات',
        ));
      } else if (actionTypeStr == 'NAVIGATE') {
        final screen = params['screen']?.toLowerCase() ?? 'pos';
        final title = params['title'] ?? 'الانتقال للشاشة';
        actions.add(AiAction(
          type: AiActionType.navigate,
          rawType: 'NAVIGATE',
          targetScreen: screen,
          title: '📋 $title',
        ));
      } else if (actionTypeStr == 'CREATE_PURCHASE_ORDER') {
        final title = params['title'] ?? 'تجهيز طلبية شراء النواقص';
        actions.add(AiAction(
          type: AiActionType.createPurchaseOrder,
          rawType: 'CREATE_PURCHASE_ORDER',
          title: '📦 $title',
        ));
      }
    }

    return actions;
  }
}
