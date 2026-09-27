// شاشة التنقل الرئيسية لتطبيق المدير - PharmaOS Owner App
import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'live_screen_cctv_screen.dart';
import 'remote_purchases_screen.dart';
import 'remote_inventory_screen.dart';
import 'live_chat_screen.dart';
import 'remote_backup_reports_screen.dart';
import 'tele_pharmacy_tab.dart';
import 'settings_tab.dart';
import 'login_screen.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';
import '../widgets/luxury_background.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  Timer? _deviceStatusTimer;
  bool _isDeviceBlocked = false;

  final List<Widget> _screens = const [
    DashboardTab(),
    LiveScreenCctvScreen(),
    RemotePurchasesScreen(),
    RemoteInventoryScreen(),
    LiveChatScreen(),
    RemoteBackupReportsScreen(),
    TelePharmacyTab(),
    SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    _startDeviceStatusChecker();
  }

  void _startDeviceStatusChecker() {
    _checkStatus();
    _deviceStatusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    final active = await OwnerApiService.isDeviceActive();
    if (!active && mounted && !_isDeviceBlocked) {
      setState(() => _isDeviceBlocked = true);
    } else if (active && mounted && _isDeviceBlocked) {
      setState(() => _isDeviceBlocked = false);
    }
  }

  @override
  void dispose() {
    _deviceStatusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeviceBlocked) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF060913),
          body: LuxuryBackground(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 54),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '⛔ تم إيقاف هذا الجهاز',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'قام مدير الصيدلية بإيقاف صلاحية هذا الهاتف من لوحة تحكم النظام المكتبي. يرجى مراجعة إدارة الصيدلية لإعادة التفعيل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('التحقق من إعادة التفعيل'),
                      onPressed: _checkStatus,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        await OwnerApiService.logout();
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        }
                      },
                      child: const Text('تسجيل الخروج والربط بصيدلية أخرى', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF060913),
        body: LuxuryBackground(
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0C1322).withOpacity(0.95),
            border: const Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: OwnerTheme.primaryEmerald.withOpacity(0.25),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: Colors.white54, size: 22),
                selectedIcon: Icon(Icons.dashboard_rounded, color: OwnerTheme.primaryEmeraldLight, size: 24),
                label: 'المبيعات',
              ),
              NavigationDestination(
                icon: Icon(Icons.videocam_outlined, color: Colors.white54, size: 22),
                selectedIcon: Icon(Icons.videocam_rounded, color: OwnerTheme.primaryEmeraldLight, size: 24),
                label: 'البث الحي',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined, color: Colors.white54, size: 22),
                selectedIcon: Icon(Icons.receipt_long_rounded, color: OwnerTheme.primaryEmeraldLight, size: 24),
                label: 'فواتير الشراء',
              ),
              NavigationDestination(
                icon: Icon(Icons.table_chart_outlined, color: Colors.white54, size: 22),
                selectedIcon: Icon(Icons.table_chart_rounded, color: OwnerTheme.primaryEmeraldLight, size: 24),
                label: 'المخزون',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined, color: Colors.white54, size: 22),
                selectedIcon: Icon(Icons.forum_rounded, color: OwnerTheme.primaryEmeraldLight, size: 24),
                label: 'الدردشة',
              ),
              NavigationDestination(
                icon: Icon(Icons.cloud_done_outlined, color: Colors.white54, size: 22),
                selectedIcon: Icon(Icons.cloud_done_rounded, color: OwnerTheme.primaryEmeraldLight, size: 24),
                label: 'النسخ والتقارير',
              ),
              NavigationDestination(
                icon: Icon(Icons.wifi_channel_outlined, color: Colors.white54, size: 22),
                selectedIcon: Icon(Icons.wifi_channel_rounded, color: OwnerTheme.primaryEmeraldLight, size: 24),
                label: 'الروشتات',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: Colors.white54, size: 22),
                selectedIcon: Icon(Icons.settings_rounded, color: OwnerTheme.primaryEmeraldLight, size: 24),
                label: 'الإعدادات',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
