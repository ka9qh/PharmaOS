// تعريف مسارات التطبيق عبر GoRouter
// نقطة البداية الفورية هي شاشة تسجيل الدخول (/login)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'splash_loading_screen.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/licensing/presentation/screens/licensing_screen.dart';
import '../features/pos/presentation/screens/pos_screen.dart';
import '../features/accounting/presentation/screens/chart_of_accounts_screen.dart';
import '../features/accounting/presentation/screens/journal_entries_screen.dart';
import '../features/returns/presentation/screens/purchase_returns_screen.dart';
import '../features/doctors/presentation/screens/doctors_screen.dart';
import '../features/prescriptions/presentation/screens/prescriptions_screen.dart';
import '../features/inventory/presentation/screens/inventory_reconciliation_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_wizard_screen.dart';
import '../features/settings/presentation/screens/devices_branches_management_screen.dart';
import '../features/chat/presentation/screens/desktop_live_chat_screen.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter build({String initialLocation = '/login'}) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/pos',
          builder: (context, state) => const PosScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/activation',
          builder: (context, state) => const LicensingScreen(),
        ),
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashLoadingScreen(),
        ),
        GoRoute(
          path: '/accounting/chart',
          builder: (context, state) => const ChartOfAccountsScreen(),
        ),
        GoRoute(
          path: '/accounting/journals',
          builder: (context, state) => const JournalEntriesScreen(),
        ),
        GoRoute(
          path: '/returns/purchase',
          builder: (context, state) => const PurchaseReturnsScreen(),
        ),
        GoRoute(
          path: '/doctors',
          builder: (context, state) => const DoctorsScreen(),
        ),
        GoRoute(
          path: '/prescriptions',
          builder: (context, state) => const PrescriptionsScreen(),
        ),
        GoRoute(
          path: '/inventory-reconciliation',
          builder: (context, state) => const InventoryReconciliationScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingWizardScreen(),
        ),
        GoRoute(
          path: '/settings/devices-branches',
          builder: (context, state) => const DevicesBranchesManagementScreen(),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const DesktopLiveChatScreen(),
        ),
      ],
    );
  }
}
