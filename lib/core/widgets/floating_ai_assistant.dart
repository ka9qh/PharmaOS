// استوديو والمساعد الصيدلاني الذكي الموحد (AI Copilot Studio) - PharmaOS
// يدمج المحادثة الذكية، الاستشارات السريرية، وبدائل الأدوية في واجهة واحدة موحدة
// متصل مباشرة بقاعدة بيانات الصيدلية الحالية، وينفذ الأوامر مع حفظ المحادثات.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/ai/presentation/providers/ai_chat_provider.dart';
import '../../features/ai/presentation/widgets/ai_chat_widget.dart';

class FloatingAiDialog extends ConsumerStatefulWidget {
  final String? initialMessage;

  const FloatingAiDialog({super.key, this.initialMessage});

  static void show(BuildContext context, {String? initialMessage}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FloatingAiDialog(initialMessage: initialMessage),
    );
  }

  @override
  ConsumerState<FloatingAiDialog> createState() => _FloatingAiDialogState();
}

class _FloatingAiDialogState extends ConsumerState<FloatingAiDialog> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _quickSuggestions = [
    'أيش الأدوية المتوفرة بالمخزون؟',
    'ما هي النواقص التي نفدت؟',
    'كم مبيعات وأرباح اليوم؟',
    'أدوية الصداع المتوفرة وبدائلها',
    'افتح شاشة المخزون والجرد',
    'افتح شاشة المبيعات (الكاشير)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialMessage);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? customText]) {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty) return;

    ref.read(aiChatNotifierProvider.notifier).send(text);
    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
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
        content: const Text('هل تريد مسح سجل المحادثات السابقة والبدء من جديد؟'),
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
            child: const Text('مسح'),
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
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          width: 880,
          height: 700,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المستشار الطبي والصيدلاني الذكي (Gemini 3.8 Flash)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Row(
                            children: [
                              Icon(Icons.circle, size: 7, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'متصل بالمخزون الحقيقي، بدائل الأدوية، والأسعار بالريال اليمني',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
                      tooltip: 'مسح سجل الدردشة',
                      onPressed: _confirmClearChat,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Suggestions Chips
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _quickSuggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) => ActionChip(
                    avatar: const Icon(Icons.flash_on, size: 14, color: Color(0xFF0D9488)),
                    label: Text(_quickSuggestions[idx], style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onPressed: () => _sendMessage(_quickSuggestions[idx]),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Messages List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: state.messages.length,
                  itemBuilder: (ctx, idx) => ChatBubble(message: state.messages[idx]),
                ),
              ),

              // Loading / Thinking indicator
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
                        state.statusMessage ?? 'جاري التفكير وفحص المخزون والتحليل السريري...',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                      ),
                    ],
                  ),
                ),

              // Input Bar
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
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'اسأل عن أي دواء، استفسر عن المخزون والأسعار، أو أطلب أمراً...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: state.isProcessing ? null : () => _sendMessage(),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
