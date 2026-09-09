// استوديو والمساعد الصيدلاني الذكي الموحد (AI Copilot Studio) - PharmaOS
// يدمج المحادثة الذكية، الاستشارات السريرية، وبدائل الأدوية في واجهة واحدة موحدة

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gemini_online_ai_service.dart';

class FloatingAiDialog extends StatefulWidget {
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
  State<FloatingAiDialog> createState() => _FloatingAiDialogState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

class _FloatingAiDialogState extends State<FloatingAiDialog> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  final List<String> _quickSuggestions = [
    'ايش بدائل سيفكس 400؟',
    'جرعة أوجمنتين 1 جم للكبار؟',
    'أدوية آمنة للصداع للحامل',
    'كم مبيعات اليوم؟',
    'ايش ناقص بالمخزون؟',
    'التفاعلات الدوائية للوارفارين',
    'علاج المغص والتقلصات المعوية',
    'بدائل بروفين 400',
  ];

  @override
  void initState() {
    super.initState();
    // رسالة الترحيب الأولى
    _messages.add(
      _ChatMessage(
        text: 'مرحباً دكتور 👨‍⚕️ أنا مساعدك الصيدلاني الذكي المدمج في PharmaOS.\n'
            'يمكنني مساعدتك في: البدائل الدوائية، الجرعات، أمان الحمل والرضاعة، التفاعلات، واستعلامات المبيعات والنواقص.',
        isUser: false,
        time: DateTime.now(),
      ),
    );

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

  Future<void> _sendMessage([String? customText]) async {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        time: DateTime.now(),
      ));
      _isTyping = true;
      _textController.clear();
    });

    _scrollToBottom();

    // استدعاء خدمة الذكاء الاصطناعي والمحرك السريري
    final response = await GeminiOnlineAiService.askAi(
      prompt: text,
    );

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(
          text: response,
          isUser: false,
          time: DateTime.now(),
        ));
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          width: 850,
          height: 680,
          decoration: BoxDecoration(
            color: Colors.white,
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
                          colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
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
                          Text('المساعد الصيدلاني الذكي (AI Copilot)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('ذكاء اصطناعي سريري، بدائل الأدوية، والجرعات الطبية',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
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
                    avatar: const Icon(Icons.flash_on, size: 14, color: Colors.indigo),
                    label: Text(_quickSuggestions[idx], style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.indigo.shade50,
                    onPressed: () => _sendMessage(_quickSuggestions[idx]),
                  ),
                ),
              ),
              const Divider(height: 1),

              // Messages List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (ctx, idx) {
                    if (idx == _messages.length && _isTyping) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo),
                              ),
                              SizedBox(width: 10),
                              Text('جاري التحليل الطبي والإجابة...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    }

                    final msg = _messages[idx];
                    return Align(
                      alignment: msg.isUser ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.58),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: msg.isUser ? const Color(0xFF6366F1) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              msg.text,
                              style: TextStyle(
                                color: msg.isUser ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            if (!msg.isUser && idx > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 15, color: Colors.blueGrey),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: msg.text));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('تم نسخ النص بنجاح'), duration: Duration(seconds: 1)),
                                      );
                                    },
                                    tooltip: 'نسخ الإجابة',
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Input Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'اسأل عن أي دواء، بديل، جرعة، أو استفسار صيدلاني...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: () => _sendMessage(),
                      child: const Icon(Icons.send, color: Colors.white, size: 18),
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
