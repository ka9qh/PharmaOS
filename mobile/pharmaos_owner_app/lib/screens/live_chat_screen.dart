// شاشة الدردشة الحية الفورية مع الصيدلية والفروع (WhatsApp-Style) - PharmaOS Owner App
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;

  List<ChatMessage> _messages = [];
  String _selectedBranch = 'كافة الفروع';
  final List<String> _branches = ['كافة الفروع', 'الفرع الرئيسي', 'فرع 2', 'كاشير الصالة'];
  bool _isSending = false;
  bool _isRecordingVoice = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadMessages(silent: true);
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final list = await OwnerApiService.fetchChatMessages(
      branchId: _selectedBranch == 'كافة الفروع' ? null : _selectedBranch,
    );
    if (mounted) {
      setState(() => _messages = list);
      if (!silent) _scrollToBottom();
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

  Future<void> _sendMessage({String? audioBase64, String? imageBase64}) async {
    final text = _textController.text.trim();
    if (text.isEmpty && audioBase64 == null && imageBase64 == null) return;

    setState(() => _isSending = true);
    _textController.clear();

    final branchId = _selectedBranch == 'كافة الفروع' ? 'main' : _selectedBranch;
    final success = await OwnerApiService.sendChatMessage(
      text: text,
      audioBase64: audioBase64,
      imageBase64: imageBase64,
      branchId: branchId,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _loadMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال الرسالة، تأكد من الاتصال')),
        );
      }
    }
  }

  void _simulateVoiceRecording() {
    setState(() => _isRecordingVoice = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isRecordingVoice = false);
        _sendMessage(audioBase64: 'VOICE_RECORDING_MOCK_DATA');
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: OwnerTheme.darkBg,
        appBar: AppBar(
          backgroundColor: OwnerTheme.darkCard,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OwnerTheme.primaryEmerald.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.forum_rounded, color: OwnerTheme.primaryEmeraldLight, size: 20),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الدردشة الحية مع الفروع 💬', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('متصل ومباشر مع الكاشيرات', style: TextStyle(fontSize: 11, color: Color(0xFF34D399))),
                ],
              ),
            ],
          ),
          actions: [
            DropdownButton<String>(
              value: _selectedBranch,
              dropdownColor: OwnerTheme.darkCard,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Cairo'),
              underline: const SizedBox(),
              items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedBranch = val);
                  _loadMessages();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // قائمة الرسائل بنمط الواتساب
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mark_chat_read_rounded, size: 60, color: Colors.white.withOpacity(0.15)),
                          const SizedBox(height: 14),
                          const Text('لا توجد رسائل سابقة مع هذا الفرع', style: TextStyle(color: Colors.white60, fontSize: 14)),
                          const SizedBox(height: 6),
                          const Text('أرسل رسالة نصية أو تسجيل صوتي وسيظهر في شاشة النظام فوراً', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isOwner = msg.senderRole == 'owner';

                        return Align(
                          alignment: isOwner ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isOwner ? OwnerTheme.primaryEmerald : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isOwner ? 2 : 16),
                                bottomRight: Radius.circular(isOwner ? 16 : 2),
                              ),
                              border: Border.all(
                                color: isOwner ? OwnerTheme.primaryEmeraldLight.withOpacity(0.5) : OwnerTheme.surfaceBorder,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOwner ? OwnerTheme.accentGoldLight : const Color(0xFF38BDF8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (msg.text.isNotEmpty)
                                  Text(
                                    msg.text,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                  ),
                                if (msg.audioBase64 != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.play_arrow_rounded, color: OwnerTheme.accentGold, size: 20),
                                        SizedBox(width: 6),
                                        Text('تسجيل صوتي (0:04)', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // شريط التسجيل والإدخال
            if (_isRecordingVoice)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.withOpacity(0.2),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('جاري تسجيل رسالة صوتية للمستخدمين...', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: OwnerTheme.darkCard,
                border: Border(top: BorderSide(color: OwnerTheme.surfaceBorder)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mic_rounded, color: OwnerTheme.accentGold),
                      tooltip: 'تسجيل صوتي',
                      onPressed: _simulateVoiceRecording,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالة للفرع المكتبي...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                          filled: true,
                          fillColor: OwnerTheme.darkCardElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, color: OwnerTheme.primaryEmeraldLight),
                      onPressed: _isSending ? null : () => _sendMessage(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
