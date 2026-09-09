// الثيم الموحد لنظام PharmaOS
// TODO: عند إضافة خط عربي فعلي (مثل Cairo) داخل assets/fonts، فعّله هنا
// وأضف تعريفه في pubspec.yaml تحت flutter/fonts.

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryColor = Color(0xFF0E7C61); // أخضر يوحي بالصحة
  static const Color dangerColor = Color(0xFFD32F2F); // للعمليات الحساسة (حذف/إلغاء)

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      appBarTheme: const AppBarTheme(centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
