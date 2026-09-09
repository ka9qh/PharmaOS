// خدمة التخصيص والتحكم الشامل في الأقسام بدون برمجة - PharmaOS
// تتيح تخصيص كل قسم من لوحة التحكم: الاسم، الأيقونة، تفعيل شريط البحث،
// إضافة أزرار وإجراءات مخصصة، بطاقات الإحصاء، والروابط السريعة.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomActionButton {
  final String id;
  final String label;
  final int iconCodePoint;
  final String actionType; // 'navigate_screen', 'open_url', 'show_alert', 'quick_filter'
  final String target; // route name, URL, message, or filter value
  final int colorValue;

  CustomActionButton({
    required this.id,
    required this.label,
    required this.iconCodePoint,
    required this.actionType,
    required this.target,
    required this.colorValue,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'iconCodePoint': iconCodePoint,
        'actionType': actionType,
        'target': target,
        'colorValue': colorValue,
      };

  factory CustomActionButton.fromJson(Map<String, dynamic> json) => CustomActionButton(
        id: json['id'] ?? '',
        label: json['label'] ?? '',
        iconCodePoint: json['iconCodePoint'] ?? Icons.smart_button.codePoint,
        actionType: json['actionType'] ?? 'navigate_screen',
        target: json['target'] ?? '',
        colorValue: json['colorValue'] ?? Colors.teal.value,
      );
}

class SectionCustomizationConfig {
  final String sectionKey;
  final String customTitle;
  final String customSubtitle;
  final bool showSearchBar;
  final bool showSummaryCards;
  final bool showDateFilter;
  final bool showExportButton;
  final bool showQuickAddButton;
  final List<CustomActionButton> customButtons;

  SectionCustomizationConfig({
    required this.sectionKey,
    required this.customTitle,
    required this.customSubtitle,
    this.showSearchBar = true,
    this.showSummaryCards = true,
    this.showDateFilter = true,
    this.showExportButton = true,
    this.showQuickAddButton = true,
    this.customButtons = const [],
  });

  SectionCustomizationConfig copyWith({
    String? customTitle,
    String? customSubtitle,
    bool? showSearchBar,
    bool? showSummaryCards,
    bool? showDateFilter,
    bool? showExportButton,
    bool? showQuickAddButton,
    List<CustomActionButton>? customButtons,
  }) {
    return SectionCustomizationConfig(
      sectionKey: sectionKey,
      customTitle: customTitle ?? this.customTitle,
      customSubtitle: customSubtitle ?? this.customSubtitle,
      showSearchBar: showSearchBar ?? this.showSearchBar,
      showSummaryCards: showSummaryCards ?? this.showSummaryCards,
      showDateFilter: showDateFilter ?? this.showDateFilter,
      showExportButton: showExportButton ?? this.showExportButton,
      showQuickAddButton: showQuickAddButton ?? this.showQuickAddButton,
      customButtons: customButtons ?? this.customButtons,
    );
  }

  Map<String, dynamic> toJson() => {
        'sectionKey': sectionKey,
        'customTitle': customTitle,
        'customSubtitle': customSubtitle,
        'showSearchBar': showSearchBar,
        'showSummaryCards': showSummaryCards,
        'showDateFilter': showDateFilter,
        'showExportButton': showExportButton,
        'showQuickAddButton': showQuickAddButton,
        'customButtons': customButtons.map((b) => b.toJson()).toList(),
      };

  factory SectionCustomizationConfig.fromJson(Map<String, dynamic> json) => SectionCustomizationConfig(
        sectionKey: json['sectionKey'] ?? '',
        customTitle: json['customTitle'] ?? '',
        customSubtitle: json['customSubtitle'] ?? '',
        showSearchBar: json['showSearchBar'] ?? true,
        showSummaryCards: json['showSummaryCards'] ?? true,
        showDateFilter: json['showDateFilter'] ?? true,
        showExportButton: json['showExportButton'] ?? true,
        showQuickAddButton: json['showQuickAddButton'] ?? true,
        customButtons: (json['customButtons'] as List?)?.map((b) => CustomActionButton.fromJson(b)).toList() ?? [],
      );
}

class SectionCustomizationService {
  static const String _prefix = 'section_config_v2_';

  static Future<SectionCustomizationConfig> getConfig(String sectionKey, {String defaultTitle = '', String defaultSubtitle = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$sectionKey');
    if (raw == null || raw.isEmpty) {
      return SectionCustomizationConfig(
        sectionKey: sectionKey,
        customTitle: defaultTitle,
        customSubtitle: defaultSubtitle,
      );
    }
    try {
      final json = jsonDecode(raw);
      return SectionCustomizationConfig.fromJson(json);
    } catch (_) {
      return SectionCustomizationConfig(
        sectionKey: sectionKey,
        customTitle: defaultTitle,
        customSubtitle: defaultSubtitle,
      );
    }
  }

  static Future<void> saveConfig(SectionCustomizationConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(config.toJson());
    await prefs.setString('$_prefix${config.sectionKey}', encoded);
  }
}
