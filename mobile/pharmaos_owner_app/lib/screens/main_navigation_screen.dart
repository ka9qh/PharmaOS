// شاشة التنقل الرئيسية لتطبيق المدير - PharmaOS Owner App
import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'tele_pharmacy_tab.dart';
import 'medicines_tab.dart';
import 'settings_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardTab(),
    TelePharmacyTab(),
    MedicinesTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: NavigationBar(
            backgroundColor: const Color(0xFF1E293B),
            indicatorColor: const Color(0xFF6366F1).withOpacity(0.3),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.dashboard_rounded, color: Colors.cyanAccent),
                label: 'المبيعات',
              ),
              NavigationDestination(
                icon: Icon(Icons.wifi_channel_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.wifi_channel_rounded, color: Colors.cyanAccent),
                label: 'الروشتات',
              ),
              NavigationDestination(
                icon: Icon(Icons.medication_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.medication_rounded, color: Colors.cyanAccent),
                label: 'الأدوية',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.settings_rounded, color: Colors.cyanAccent),
                label: 'الإعدادات',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
