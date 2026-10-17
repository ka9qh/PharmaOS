// مزود محادثة المساعد الصيدلاني الذكي (Gemini Online AI + RAG + Persistent Memory) - PharmaOS

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gemini_online_ai_service.dart';
import '../../../../core/services/ai_chat_history_service.dart';

export '../../../../core/services/ai_chat_history_service.dart' show AiChatMessage, AiAction, AiActionType;

// للاستخدام القديم المتوافق
typedef ChatMessage = AiChatMessage;

class AiChatState {
  final List<AiChatMessage> messages;
  final bool isProcessing;
  final String? statusMessage;

  const AiChatState({
    this.messages = const [],
    this.isProcessing = false,
    this.statusMessage,
  });

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isProcessing,
    String? statusMessage,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      statusMessage: statusMessage,
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() {
    _initChatHistory();
    return const AiChatState(
      messages: [],
      isProcessing: true,
      statusMessage: 'جاري استرجاع سجل المحادثات...',
    );
  }

  Future<void> _initChatHistory() async {
    final history = await AiChatHistoryService.loadMessages();
    state = AiChatState(messages: history, isProcessing: false);
  }

  Future<void> send(String question) async {
    final cleanQ = question.trim();
    if (cleanQ.isEmpty) return;

    final userMsg = AiChatMessage(
      text: cleanQ,
      isUser: true,
    );

    final currentMessages = [...state.messages, userMsg];
    state = state.copyWith(
      messages: currentMessages,
      isProcessing: true,
      statusMessage: 'جاري فحص المخزون والتحليل السريري...',
    );
    await AiChatHistoryService.saveMessages(currentMessages);

    try {
      final answer = await GeminiOnlineAiService.askAi(
        prompt: cleanQ,
        chatHistory: currentMessages,
      );

      final actions = AiChatHistoryService.parseActions(answer);
      final aiMsg = AiChatMessage(
        text: answer,
        isUser: false,
        actions: actions,
      );

      final updatedMessages = [...state.messages, aiMsg];
      state = state.copyWith(
        messages: updatedMessages,
        isProcessing: false,
      );
      await AiChatHistoryService.saveMessages(updatedMessages);
    } catch (e) {
      final errorMsg = AiChatMessage(
        text: '⚠️ تعذر إكمال الاستعلام عبر الذكاء الاصطناعي: $e\nيرجى التأكد من اتصال الإنترنت أو المحاولة مجدداً.',
        isUser: false,
      );
      final updatedMessages = [...state.messages, errorMsg];
      state = state.copyWith(
        messages: updatedMessages,
        isProcessing: false,
      );
      await AiChatHistoryService.saveMessages(updatedMessages);
    }
  }

  /// مسح سجل المحادثات والبدء من جديد
  Future<void> clearChat() async {
    state = state.copyWith(isProcessing: true);
    await AiChatHistoryService.clearHistory();
    final fresh = await AiChatHistoryService.loadMessages();
    state = AiChatState(messages: fresh, isProcessing: false);
  }

  /// تحديث حالة الأمر بأنه تم تنفيذه
  Future<void> markActionExecuted(String messageId, int actionIndex) async {
    final updated = state.messages.map((m) {
      if (m.id == messageId && actionIndex < m.actions.length) {
        m.actions[actionIndex].isExecuted = true;
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
    await AiChatHistoryService.saveMessages(updated);
  }
}

final aiChatNotifierProvider =
    NotifierProvider<AiChatNotifier, AiChatState>(() => AiChatNotifier());
