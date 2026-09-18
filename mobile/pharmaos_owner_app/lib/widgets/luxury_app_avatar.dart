// أفاتار وشعار فخم واحترافي لتطبيق المدير - PharmaOS Luxury Owner Avatar
import 'package:flutter/material.dart';

class LuxuryAppAvatar extends StatelessWidget {
  final double size;
  final bool showBadge;
  final String? badgeText;
  final bool showGlow;
  final bool isOnline;
  final VoidCallback? onTap;

  const LuxuryAppAvatar({
    super.key,
    this.size = 64,
    this.showBadge = false,
    this.badgeText,
    this.showGlow = true,
    this.isOnline = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 1. هالة الإشعاع الضوئية الخلفية (Ambient Radiant Glow)
        if (showGlow)
          Container(
            width: size * 1.18,
            height: size * 1.18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.05,
                ),
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  blurRadius: size * 0.45,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
          ),

        // 2. الإطار المعدني المزدوج المتدرج (Dual Gold & Emerald Bezel Ring)
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.04),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFF10B981),
                Color(0xFFF59E0B),
                Color(0xFF06B6D4),
                Color(0xFF6366F1),
                Color(0xFF10B981),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.all(size * 0.03),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF060913),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/owner_avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.medical_services_rounded,
                        color: Colors.white,
                        size: size * 0.48,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // 3. شارة الحالة التنفيذية أو التواجد المباشر (Online / VIP Badge)
        if (showBadge || isOnline)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: badgeText != null ? 6 : 4,
                vertical: badgeText != null ? 2 : 4,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF060913), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: badgeText != null
                  ? Text(
                      badgeText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
