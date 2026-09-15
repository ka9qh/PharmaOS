// واجهة الدردشة الحية المباشرة مع المدير العام - PharmaOS Desktop
import 'package:flutter/material.dart';
import '../../../../core/models/live_remote_models.dart';
import '../../../../core/services/owner_live_sync_service.dart';
import '../../../../core/widgets/owner_floating_notification.dart';

class DesktopLiveChatScreen extends StatefulWidget {
  const DesktopLiveChatScreen({super.key});

  @override
  State<DesktopLiveChatScreen> createState() => _DesktopLiveChatScreenState();
}

class _DesktopLiveChatScreenState extends State<DesktopLiveChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    OwnerFloatingNotification.clearUnreadChat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
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

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _textController.clear();

    final success = await OwnerLiveSyncService.sendChatMessage(text: text);
    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال الرسالة، تأكد من اتصال الإنترنت')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF14B8A6), size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مركز الربط المباشر والدردشة مع المدير',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: OwnerLiveSyncService.isConnectedNotifier,
                    builder: (context, connected, _) {
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: connected ? const Color(0xFF10B981) : Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            connected ? 'متصل سحابياً مع هاتف المدير' : 'جاهز للمزامنة',
                            style: TextStyle(
                              fontSize: 12,
                              color: connected ? const Color(0xFF10B981) : Colors.white60,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF14B8A6),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(
                icon: Icon(Icons.chat_bubble_rounded),
                text: 'الدردشة الحية مع المدير',
              ),
              Tab(
                icon: Icon(Icons.history_edu_rounded),
                text: 'سجل أوامر وتعديلات المدير',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              tooltip: 'تحديث المحادثة',
              onPressed: () => setState(() {}),
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // 1. تبويب الدردشة الحية
            _buildChatTab(),

            // 2. تبويب سجل أوامر وتعديلات المدير
            _buildAuditTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        // قائمة الرسائل
        Expanded(
          child: ValueListenableBuilder<List<ChatMessage>>(
            valueListenable: OwnerLiveSyncService.chatMessagesNotifier,
            builder: (context, messages, _) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.white.withOpacity(0.15)),
                          const SizedBox(height: 16),
                          const Text(
                            'لا توجد رسائل سابقة مع المدير',
                            style: TextStyle(color: Colors.white60, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'اكتب رسالتك الآن وستصل فورياً لتطبيق هاتف المدير بإشعار فوري',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderRole != 'owner';

                      return Align(
                        alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF0D9488) : const Color(0xFF334155),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 2 : 16),
                              bottomRight: Radius.circular(isMe ? 16 : 2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isMe ? Icons.person_rounded : Icons.admin_panel_settings_rounded,
                                    size: 14,
                                    color: isMe ? Colors.white70 : const Color(0xFF38BDF8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    msg.senderName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isMe ? Colors.white70 : const Color(0xFF38BDF8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (msg.text.isNotEmpty)
                                Text(
                                  msg.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
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
                                      Icon(Icons.mic_rounded, color: Colors.amber, size: 18),
                                      SizedBox(width: 8),
                                      Text('تسجيل صوتي من المدير', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // حقل إدخال الرسالة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(top: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك للمدير العام هنا...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ],
        );
  }

  Widget _buildAuditTab() {
    return ValueListenableBuilder<List<OwnerAuditAction>>(
      valueListenable: OwnerLiveSyncService.auditLogsNotifier,
      builder: (context, logs, _) {
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد أوامر أو تعديلات عن بعد حتى الآن',
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أي تعديل أسعار أو إضافة دواء أو مورد أو نسخ احتياطي صادر من هاتف المدير سيظهر هنا فوراً',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            IconData icon = Icons.info_outline_rounded;
            Color iconColor = const Color(0xFF38BDF8);

            if (log.actionType.contains('price')) {
              icon = Icons.price_change_rounded;
              iconColor = const Color(0xFF0EA5E9);
            } else if (log.actionType.contains('medicine')) {
              icon = Icons.medication_rounded;
              iconColor = const Color(0xFF8B5CF6);
            } else if (log.actionType.contains('supplier')) {
              icon = Icons.local_shipping_rounded;
              iconColor = const Color(0xFFF59E0B);
            } else if (log.actionType.contains('purchase')) {
              icon = Icons.receipt_long_rounded;
              iconColor = const Color(0xFFEAB308);
            } else if (log.actionType.contains('backup')) {
              icon = Icons.cloud_done_rounded;
              iconColor = const Color(0xFF10B981);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              log.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}:${log.createdAt.second.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          log.description,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'المصدر: ${log.performedBy}',
                            style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

