// شاشة المستشار الطبي والصيدلاني الذكي - PharmaOS
// متصل مباشرة بقاعدة البيانات الحية والمخزون، وينفذ الأوامر مع حفظ المحادثات.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ai_chat_provider.dart';
import '../widgets/ai_chat_widget.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  static const _suggestions = [
    'أيش الأدوية المتوفرة بالمخزون؟',
    'ما هي النواقص التي نفدت؟',
    'كم مبيعات وأرباح الفترة؟',
    'أدوية الصداع المتوفرة وبدائلها',
    'افتح شاشة المخزون والجرد',
    'افتح شاشة المبيعات (الكاشير)',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? presetText]) {
    final text = presetText ?? _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(aiChatNotifierProvider.notifier).send(text);
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('مسح سجل الدردشة'),
          ],
        ),
        content: const Text('هل أنت متأكد من رغبتك في مسح المحادثات السابقة والبدء من جديد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(aiChatNotifierProvider.notifier).clearChat();
            },
            child: const Text('مسح السجل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 1,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المستشار الطبي والصيدلاني الذكي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    'متصل بالمخزون وقاعدة البيانات الحية (Gemini 3.8 Flash)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.grey),
              tooltip: 'مسح سجل الدردشة',
              onPressed: _confirmClearChat,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: state.messages.length,
                itemBuilder: (context, index) => ChatBubble(message: state.messages[index]),
              ),
            ),
            if (state.isProcessing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.statusMessage ?? 'جاري التفكير وتحليل البيانات...',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                    ),
                  ],
                ),
              ),
            Container(
              height: 44,
              margin: const EdgeInsets.only(top: 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _suggestions
                    .map((s) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChatSuggestionChip(label: s, onTap: () => _send(s)),
                        ))
                    .toList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'اسأل عن أي دواء أو مخزون أو أطلب أمراً (مثال: أضف بنادول للسلة)...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: state.isProcessing ? null : () => _send(),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
