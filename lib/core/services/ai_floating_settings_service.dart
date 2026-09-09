// خدمة تخصيص ظهور الزر العائم للذكاء الاصطناعي - PharmaOS
// تتيح للصيدلي تحديد مكان ظهور الزر العائم (فقط في شاشة المبيعات POS، في كل مكان، أو إخفائه)

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiFloatingSettingsService {
  static const String _prefAiLocation = 'ai_floating_location_v1';
  static final ValueNotifier<String> locationNotifier = ValueNotifier<String>('pos_only');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final loc = prefs.getString(_prefAiLocation) ?? 'pos_only';
    locationNotifier.value = loc;
  }

  static Future<String> getLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAiLocation) ?? 'pos_only';
  }

  static Future<void> setLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAiLocation, location);
    locationNotifier.value = location;
  }
}
