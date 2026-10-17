// مزود محادثة المساعد الصيدلاني الذكي (Gemini Online AI + RAG) - PharmaOS

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gemini_online_ai_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  const ChatMessage({required this.text, required this.isUser});
}

class AiChatState {
  final List<ChatMessage> messages;
  final bool isProcessing;

  const AiChatState({this.messages = const [], this.isProcessing = false});

  AiChatState copyWith({List<ChatMessage>? messages, bool? isProcessing}) {
    return AiChatState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class AiChatNotifier extends AutoDisposeNotifier<AiChatState> {
  @override
  AiChatState build() {
    return const AiChatState(messages: [
      ChatMessage(
        text: 'مرحبًا بك دكتور 👨‍⚕️ أنا مستشارك الطبي والصيدلاني الذكي المدمج في PharmaOS (مدعوم بنموذج Google Gemini 3.8 Flash المتطور).\n'
            'اسألني عن أي استشارة طبية أو تشخيص أولي، دواعي الاستعمال، الجرعات للكبار والأطفال، التداخلات الدوائية، البدائل المتطابقة، أو استعلم فوراً عن المخزون والأسعار والمبيعات.',
        isUser: false,
      ),
    ]);
  }

  Future<void> send(String question) async {
    if (question.trim().isEmpty) return;

    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: question, isUser: true)],
      isProcessing: true,
    );

    try {
      final answer = await GeminiOnlineAiService.askAi(prompt: question);
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(text: answer, isUser: false)],
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          const ChatMessage(text: 'حدث خطأ أثناء معالجة السؤال، حاول مرة أخرى.', isUser: false),
        ],
        isProcessing: false,
      );
    }
  }
}

final aiChatNotifierProvider =
    AutoDisposeNotifierProvider<AiChatNotifier, AiChatState>(() => AiChatNotifier());
