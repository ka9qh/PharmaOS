// خدمة إدارة الأجهزة والفروع ورموز الاقتران والتفعيل - PharmaOS
// تدعم الصيدليات الفردية والشبكات المحلية ومتعددة الفروع مع عزل تام وتوليد رموز فريدة

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../di/service_locator.dart';

enum TopologyMode {
  singleDevice,       // جهاز فردي مستقل
  multiDeviceNetwork, // عدة أجهزة كاشير في نفس الصيدلية
  multiBranch,        // صيدلية رئيسية ولها عدة فروع
}

class BranchConfig {
  final String id;
  final String name;
  final String code;
  final String token;
  final DateTime createdAt;

  BranchConfig({
    required this.id,
    required this.name,
    required this.code,
    required this.token,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'token': token,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BranchConfig.fromJson(Map<String, dynamic> json) => BranchConfig(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        code: json['code'] ?? '',
        token: json['token'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class DeviceConfig {
  final String id;
  final String branchId;
  final String name;
  final String token;
  final bool isMainServer;
  final DateTime createdAt;

  DeviceConfig({
    required this.id,
    required this.branchId,
    required this.name,
    required this.token,
    this.isMainServer = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'branchId': branchId,
        'name': name,
        'token': token,
        'isMainServer': isMainServer,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DeviceConfig.fromJson(Map<String, dynamic> json) => DeviceConfig(
        id: json['id'] ?? '',
        branchId: json['branchId'] ?? 'main',
        name: json['name'] ?? '',
        token: json['token'] ?? '',
        isMainServer: json['isMainServer'] ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class DeviceBranchManagerService {
  static const String _prefTopologyMode = 'pharmacy_topology_mode_v1';
  static const String _prefBranchesList = 'pharmacy_branches_list_v1';
  static const String _prefDevicesList = 'pharmacy_devices_list_v1';
  static const String _prefFirstRunCompleted = 'first_run_onboarding_completed_v1';

  static Future<bool> isFirstRunCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefFirstRunCompleted) ?? false;
  }

  static Future<void> markFirstRunCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefFirstRunCompleted, true);
  }

  static Future<TopologyMode> getTopologyMode() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_prefTopologyMode) ?? 'singleDevice';
    switch (str) {
      case 'multiDeviceNetwork':
        return TopologyMode.multiDeviceNetwork;
      case 'multiBranch':
        return TopologyMode.multiBranch;
      default:
        return TopologyMode.singleDevice;
    }
  }

  static Future<void> setTopologyMode(TopologyMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTopologyMode, mode.name);
  }

  static Future<List<BranchConfig>> getBranches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefBranchesList);
    if (raw == null || raw.isEmpty) {
      // فرع رئيسي افتراضي
      final defaultMain = BranchConfig(
        id: 'main',
        name: 'الفرع الرئيسي',
        code: 'BR-01',
        token: _generateSecureToken('MAIN-BRANCH'),
        createdAt: DateTime.now(),
      );
      return [defaultMain];
    }
    try {
      final List list = jsonDecode(raw);
      return list.map((e) => BranchConfig.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBranches(List<BranchConfig> branches) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(branches.map((e) => e.toJson()).toList());
    await prefs.setString(_prefBranchesList, raw);
  }

  static Future<List<DeviceConfig>> getDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefDevicesList);
    if (raw == null || raw.isEmpty) {
      final defaultDev = DeviceConfig(
        id: 'dev-1',
        branchId: 'main',
        name: 'جهاز الإدارة الرئيسي (Server)',
        token: _generateSecureToken('DEV-01'),
        isMainServer: true,
        createdAt: DateTime.now(),
      );
      return [defaultDev];
    }
    try {
      final List list = jsonDecode(raw);
      return list.map((e) => DeviceConfig.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveDevices(List<DeviceConfig> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(devices.map((e) => e.toJson()).toList());
    await prefs.setString(_prefDevicesList, raw);
  }

  /// إنشاء فرع جديد وتوليد رمز تفعيل واقتران فريد له
  static Future<BranchConfig> addBranch({required String name, required String code}) async {
    final branches = await getBranches();
    final newBranch = BranchConfig(
      id: 'br-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      code: code,
      token: _generateSecureToken(code),
      createdAt: DateTime.now(),
    );
    branches.add(newBranch);
    await saveBranches(branches);
    return newBranch;
  }

  /// إضافة جهاز جديد وتوليد رمز تفعيل له
  static Future<DeviceConfig> addDevice({
    required String branchId,
    required String name,
    bool isMainServer = false,
  }) async {
    final devices = await getDevices();
    final newDev = DeviceConfig(
      id: 'dev-${DateTime.now().millisecondsSinceEpoch}',
      branchId: branchId,
      name: name,
      token: _generateSecureToken('DEV-${devices.length + 1}'),
      isMainServer: isMainServer,
      createdAt: DateTime.now(),
    );
    devices.add(newDev);
    await saveDevices(devices);
    return newDev;
  }

  /// حذف جهاز
  static Future<void> removeDevice(String deviceId) async {
    final devices = await getDevices();
    devices.removeWhere((d) => d.id == deviceId);
    await saveDevices(devices);
  }

  /// حذف فرع
  static Future<void> removeBranch(String branchId) async {
    final branches = await getBranches();
    branches.removeWhere((b) => b.id == branchId);
    await saveBranches(branches);
  }

  /// توليد رمز تفعيل واقتران فريد ومحمي
  static String _generateSecureToken(String prefix) {
    final random = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final part1 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    final part2 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    final part3 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'PHOS-$prefix-$part1-$part2-$part3';
  }

  /// توليد كود طلب التفعيل الذكي الذي يحتوي على اسم الصيدلية
  static Future<String> generatePharmacyActivationRequestCode(String pharmacyName, String hardwareId) async {
    final cleanName = pharmacyName.trim().replaceAll(' ', '_');
    return '$cleanName#$hardwareId';
  }
}
