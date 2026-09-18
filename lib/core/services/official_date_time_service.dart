// خدمة الوقت اللحظي والتاريخ الرسمي ومراقبة منتصف الليل - PharmaOS
// تحسب الوقت بدقة وترصد تغير التاريخ التلقائي لإطلاق النسخ الاحتياطي الثلاثي

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'multi_destination_backup_service.dart';

class OfficialDateTimeService {
  static const String _prefLastKnownDate = 'official_last_known_date_v1';
  static Timer? _midnightCheckTimer;
  static Timer? _secondTimer;
  static final StreamController<DateTime> _timeStreamController = StreamController<DateTime>.broadcast();
  static final StreamController<DateTime> _secondStreamController = StreamController<DateTime>.broadcast();

  static Stream<DateTime> get timeStream => _timeStreamController.stream;
  static Stream<DateTime> get secondStream => _secondStreamController.stream;
  static DateTime get now => DateTime.now();

  /// بدء خدمة مراقبة الوقت وتغير التاريخ
  static void initialize() {
    _midnightCheckTimer?.cancel();
    _secondTimer?.cancel();
    
    // فحص فوري عند تشغيل التطبيق: هل مر يوم جديد منذ آخر تشغيل؟
    _checkDateChangeAndTrigger();

    // مؤقت يتكرر كل ثانية لتحديث عدادات الساعة الحية في واجهة البيع والشاشات
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondStreamController.add(DateTime.now());
    });

    // مؤقت يتكرر كل دقيقة لتحديث الوقت وفحص انتقال التاريخ (00:00 منتصف الليل)
    _midnightCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _timeStreamController.add(DateTime.now());
      _checkDateChangeAndTrigger();
    });
    
    debugPrint('🕒 OfficialDateTimeService initialized. Tracking live clocks & midnight date rollover.');
  }

  /// إيقاف المراقبة عند إغلاق التطبيق
  static void dispose() {
    _midnightCheckTimer?.cancel();
    _secondTimer?.cancel();
  }

  /// فحص هل تغير التاريخ الرسمي منذ آخر فحص مسجل
  static Future<void> _checkDateChangeAndTrigger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDateStr = prefs.getString(_prefLastKnownDate);
      final currentDateStr = _formatDateOnly(DateTime.now());

      if (lastDateStr == null) {
        // أول تشغيل نسجل تاريخ اليوم
        await prefs.setString(_prefLastKnownDate, currentDateStr);
        return;
      }

      if (lastDateStr != currentDateStr) {
        debugPrint('📅 New date detected! ($lastDateStr -> $currentDateStr). Triggering Automated Midnight Backup...');
        await prefs.setString(_prefLastKnownDate, currentDateStr);
        
        // إطلاق النسخ الاحتياطي الثلاثي التلقائي فوراً
        await MultiDestinationBackupService.performFullBackup(
          triggerReason: 'نسخ تلقائي مجدول عند بداية تاريخ جديد (منتصف الليل)',
          isSilent: true,
        );
      }
    } catch (e) {
      debugPrint('Error in _checkDateChangeAndTrigger: $e');
    }
  }

  static String _formatDateOnly(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// تنسيق الوقت الحي بدقة الثواني: 08:35:12 ص
  static String formatLiveTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')} $period';
  }

  /// تنسيق التاريخ مع اسم اليوم بالعربية: الجمعة 18 سبتمبر 2026
  static String formatDateArabicWithDay(DateTime dt) {
    const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName، ${dt.day} $monthName ${dt.year}م';
  }

  /// تنسيق المدة المنقضية: 4 ساعات و 15 دقيقة
  static String formatElapsedDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours ساعة و $minutes دقيقة';
    }
    return '$minutes دقيقة';
  }

  /// تنسيق التاريخ والوقت العربي الرسمي
  static String formatOfficialDateTime(DateTime dt) {
    final date = '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'م' : 'ص';
    final time = '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')} $period';
    return '$date - $time';
  }
}
