import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../pos/presentation/providers/pos_provider.dart';
import '../../../pos/presentation/screens/pos_screen.dart';
import '../../../medicines/presentation/screens/medicines_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../needed_items/presentation/screens/needed_items_screen.dart';
import '../../../customers/presentation/screens/customers_screen.dart';
import '../../../suppliers/presentation/screens/suppliers_screen.dart';
import '../../../purchases/presentation/screens/purchases_screen.dart';

import '../providers/ai_chat_provider.dart';

class ChatBubble extends ConsumerWidget {
  final AiChatMessage message;
  const ChatBubble({super.key, required this.message});

  Future<void> _handleAction(BuildContext context, WidgetRef ref, AiAction action, int index) async {
    if (action.isExecuted) return;

    try {
      if (action.type == AiActionType.addToCart && action.medicineId != null) {
        final medRepo = sl<MedicinesRepository>();
        final med = await medRepo.getById(action.medicineId!);
        if (med != null) {
          final unitPrice = action.price ?? med.sellingPrice;
          await ref.read(posNotifierProvider.notifier).addMedicineWithQuantity(
                med,
                action.quantity,
                med.unit,
                1,
                unitPrice,
              );

          await ref.read(aiChatNotifierProvider.notifier).markActionExecuted(message.id, index);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ تمت إضافة "${action.medicineName ?? med.nameAr}" (${action.quantity} ${med.unit}) لسلة المبيعات بنجاح!',
                  textDirection: TextDirection.rtl,
                ),
                backgroundColor: const Color(0xFF059669),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ لم يتم العثور على سجل الدواء في قاعدة البيانات'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else if (action.type == AiActionType.navigate && action.targetScreen != null) {
        await ref.read(aiChatNotifierProvider.notifier).markActionExecuted(message.id, index);
        if (!context.mounted) return;

        Widget targetWidget;
        switch (action.targetScreen!.toLowerCase()) {
          case 'pos':
            targetWidget = const PosScreen();
            break;
          case 'inventory':
            targetWidget = const MedicinesScreen();
            break;
          case 'shortages':
            targetWidget = const NeededItemsScreen();
            break;
          case 'reports':
            targetWidget = const ReportsScreen();
            break;
          case 'customers':
            targetWidget = const CustomersScreen();
            break;
          case 'suppliers':
            targetWidget = const SuppliersScreen();
            break;
          case 'purchases':
            targetWidget = const PurchasesScreen();
            break;
          default:
            targetWidget = const PosScreen();
        }

        Navigator.of(context).push(MaterialPageRoute(builder: (_) => targetWidget));
      } else if (action.type == AiActionType.createPurchaseOrder) {
        await ref.read(aiChatNotifierProvider.notifier).markActionExecuted(message.id, index);
        if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NeededItemsScreen()));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تنفيذ الأمر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final timeStr =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 2 : 16),
            bottomRight: Radius.circular(isUser ? 16 : 2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ترويسة الرسالة مع الشعار والوقت
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person : Icons.medical_services_rounded,
                  size: 14,
                  color: isUser ? Colors.white70 : const Color(0xFF0D9488),
                ),
                const SizedBox(width: 6),
                Text(
                  isUser ? 'الصيدلي' : 'المستشار الطبي والدوائي (Gemini AI)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isUser ? Colors.white70 : const Color(0xFF0F766E),
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white60 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // نص الرسالة النظيف
            SelectableText(
              message.cleanDisplayText,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isUser ? Colors.white : const Color(0xFF1E293B),
              ),
            ),

            // الأوامر والإجراءات التفاعلية (Action Cards)
            if (message.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt, size: 14, color: Color(0xFFF59E0B)),
                        SizedBox(width: 4),
                        Text(
                          'أوامر وإجراءات سريعة مقترحة:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: message.actions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final action = entry.value;

                        final isExecuted = action.isExecuted;
                        final color = isExecuted
                            ? const Color(0xFF10B981)
                            : (action.type == AiActionType.addToCart
                                ? const Color(0xFF0D9488)
                                : const Color(0xFF4F46E5));

                        return ActionChip(
                          avatar: Icon(
                            isExecuted ? Icons.check_circle : (action.type == AiActionType.addToCart ? Icons.add_shopping_cart : Icons.arrow_outward),
                            size: 16,
                            color: isExecuted ? Colors.white : color,
                          ),
                          label: Text(
                            isExecuted ? '${action.title} (تم التنفيذ ✅)' : action.title,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isExecuted ? Colors.white : color,
                            ),
                          ),
                          backgroundColor: isExecuted ? const Color(0xFF059669) : color.withValues(alpha: 0.08),
                          side: BorderSide(color: color.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onPressed: isExecuted ? null : () => _handleAction(context, ref, action, idx),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChatSuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const ChatSuggestionChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: onTap,
    );
  }
}
