// خلفية فاخرة واحترافية متطورة لتطبيق المدير - PharmaOS Luxury Owner Background
import 'package:flutter/material.dart';

class LuxuryBackground extends StatelessWidget {
  final Widget child;
  final bool showAmbientGlow;
  final bool showGridPattern;

  const LuxuryBackground({
    super.key,
    required this.child,
    this.showAmbientGlow = true,
    this.showGridPattern = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. التدرج الأساسي العميق والفخم (Deep Obsidian & Midnight Velvet)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF060913),
                  Color(0xFF0A1022),
                  Color(0xFF0D1730),
                  Color(0xFF080C17),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        // 2. الهالات الضوئية المحيطية الذكية (Ambient Glowing Orbs)
        if (showAmbientGlow) ...[
          // هالة علوية زمردية-تركوازية (Emerald / Teal Glow) ترمز للنمو والنجاح الصيدلاني
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.18),
                    const Color(0xFF06B6D4).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // هالة سفلية ملكية نيلي/بنفسجي (Royal Indigo Glow) ترمز للتحكم والسيادة
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.15),
                    const Color(0xFF3B82F6).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // هالة ذهبية ناعمة في الوسط ترمز للثروة والأرباح والمبيعات
          Positioned(
            top: 280,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ],

        // 3. شبكة هندسية دقيقة فاخرة (Dot Matrix & Cyber Luxury Mesh)
        if (showGridPattern)
          Positioned.fill(
            child: CustomPaint(
              painter: _LuxuryMeshPatternPainter(),
            ),
          ),

        // 4. المحتوى الفعلي
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

class _LuxuryMeshPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.015)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    const double spacing = 32.0;
    final int cols = (size.width / spacing).ceil();
    final int rows = (size.height / spacing).ceil();

    // رسم مصفوفة النقاط الدقيقة
    for (int i = 0; i <= cols; i++) {
      for (int j = 0; j <= rows; j++) {
        final x = i * spacing;
        final y = j * spacing;
        
        // نقاط صغيرة تعطي إحساس التقنية العالية
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);

        // خطوط قطرية خفيفة جداً ومتقاطعة لبعض الخلايا كلمسة جمالية
        if ((i + j) % 6 == 0) {
          canvas.drawLine(Offset(x, y), Offset(x + spacing, y + spacing), linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
