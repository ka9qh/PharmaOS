// شاشة التنقل الرئيسية لتطبيق المدير - PharmaOS Owner App
import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'live_screen_cctv_screen.dart';
import 'remote_purchases_screen.dart';
import 'remote_inventory_screen.dart';
import 'live_chat_screen.dart';
import 'remote_backup_reports_screen.dart';
import 'tele_pharmacy_tab.dart';
import 'settings_tab.dart';
import '../theme/owner_theme.dart';
import '../widgets/luxury_background.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

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
  Widget build(BuildContext context) {
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
            color: const Color(0xFF0C1322).withValues(alpha: 0.95),
            border: const Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: OwnerTheme.primaryEmerald.withValues(alpha: 0.25),
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
