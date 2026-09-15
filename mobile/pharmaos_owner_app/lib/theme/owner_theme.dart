// ثيم تطبيق المدير الاحترافي الفاخر - PharmaOS Owner Theme
// تصميم Glassmorphism باللون الزمردي والداكن والذهبي
import 'package:flutter/material.dart';

class OwnerTheme {
  // الألوان الأساسية
  static const Color primaryEmerald = Color(0xFF059669);
  static const Color primaryEmeraldLight = Color(0xFF10B981);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color accentGoldLight = Color(0xFFFBBF24);
  static const Color darkBg = Color(0xFF0A0F1D);
  static const Color darkCard = Color(0xFF131B2E);
  static const Color darkCardElevated = Color(0xFF1E293B);
  static const Color surfaceBorder = Color(0xFF2A364F);

  // تدرجات لونية فاخرة
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF162032), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient bgMeshGradient = LinearGradient(
    colors: [Color(0xFF0B132B), Color(0xFF080C16), Color(0xFF0A192F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // إعدادات الثيم العام
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryEmerald,
      colorScheme: const ColorScheme.dark(
        primary: primaryEmeraldLight,
        secondary: accentGold,
        surface: darkCard,
        background: darkBg,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.white,
      ),
      fontFamily: 'Cairo',
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryEmerald,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryEmeraldLight, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      ),
    );
  }

  // زخرفة البطاقات الزجاجية Glassmorphism
  static BoxDecoration glassCardDecoration({
    Color? borderColor,
    double borderRadius = 18,
    Color? bgColor,
  }) {
    return BoxDecoration(
      color: bgColor ?? const Color(0xFF131C31).withOpacity(0.85),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? const Color(0xFF2A3958).withOpacity(0.6),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
