// لوحة التحكم الرئيسية الاحترافية - PharmaOS
// تصميم متميز مع زر نقطة البيع البارز بالأعلى، استبدال التقارير بإغلاق اليومية،
// بطاقات الإحصائيات في الأسفل، المساعد الذكي العائم، والربط الشامل.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/notifications/presentation/widgets/notifications_widget.dart';
import '../features/dashboard/presentation/widgets/dashboard_widget.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/reports/presentation/providers/reports_provider.dart';
import '../features/analytics/presentation/providers/analytics_provider.dart';
import '../features/stock_alerts/presentation/providers/stock_alerts_provider.dart';
import '../features/notifications/presentation/providers/notifications_provider.dart';
import '../features/audit_logs/presentation/providers/audit_logs_provider.dart';
import '../core/widgets/owner_floating_notification.dart';
import '../features/chat/presentation/screens/desktop_live_chat_screen.dart';

import '../features/medicines/presentation/screens/medicines_screen.dart';
import '../features/categories/presentation/screens/categories_screen.dart';
import '../features/companies/presentation/screens/companies_screen.dart';
import '../features/inventory/presentation/screens/inventory_screen.dart';
import '../features/suppliers/presentation/screens/suppliers_screen.dart';
import '../features/purchases/presentation/screens/purchases_screen.dart';
import '../features/purchases/presentation/screens/vendor_payments_screen.dart';
import '../features/invoices/presentation/screens/invoices_screen.dart';
import '../features/expenses/presentation/screens/expenses_screen.dart';
import '../features/closing/presentation/screens/daily_closing_screen.dart';
import '../features/analytics/presentation/screens/analytics_screen.dart';
import '../features/stock_alerts/presentation/screens/stock_alerts_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/audit_logs/presentation/screens/audit_logs_screen.dart';
import '../features/users/presentation/screens/users_screen.dart';
import '../features/permissions/presentation/screens/permissions_screen.dart';
import '../features/customers/presentation/screens/customers_screen.dart';
import '../features/backup/presentation/screens/backup_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/suppliers/presentation/screens/pharmacy_debts_screen.dart';
import '../features/workers/presentation/screens/workers_screen.dart';
import '../features/suppliers/presentation/screens/active_suppliers_screen.dart';
import '../features/companies/presentation/screens/active_companies_screen.dart';
import '../features/suppliers/presentation/screens/medicine_supplier_finder_screen.dart';
import '../features/medicines/presentation/screens/wanted_medicines_screen.dart';
import '../core/widgets/floating_ai_assistant.dart';
import '../features/settings/presentation/screens/dashboard_layout_manager_screen.dart';
import '../features/inventory/presentation/widgets/receive_stock_dialog.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/hardware/presentation/screens/hardware_management_screen.dart';
import '../features/doctors/presentation/screens/doctors_screen.dart';
import '../features/prescriptions/presentation/screens/prescriptions_screen.dart';
import '../features/prescriptions/presentation/screens/tele_consultation_dialog.dart';
import '../features/owner_app/presentation/screens/owner_portal_screen.dart';
import '../features/inventory/presentation/screens/inventory_reconciliation_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final reportsState = ref.watch(reportsNotifierProvider);
    final notificationsState = ref.watch(notificationsNotifierProvider);
    final preview = reportsState.preview;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_pharmacy, color: Colors.blue),
              ),
              const SizedBox(width: 10),
              const Text('لوحة التحكم - PharmaOS'),
            ],
          ),
          actions: [
            ValueListenableBuilder<int>(
              valueListenable: OwnerFloatingNotification.unreadMessagesCount,
              builder: (context, unread, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'الدردشة الحية مع المدير العام',
                      icon: const Icon(Icons.forum_rounded, color: Color(0xFF0D9488)),
                      onPressed: () => _navigate(context, const DesktopLiveChatScreen()),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            NotificationBellIcon(
              count: notificationsState.count,
              onTap: () => _navigate(context, const NotificationsScreen()),
            ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
              onPressed: () {
                ref.read(authNotifierProvider.notifier).logout();
                context.go('/login');
              },
            ),
          ],
        ),
        body: RefreshIndicator(
            onRefresh: () async {
              await ref.read(reportsNotifierProvider.notifier).loadInitial();
              await ref.read(analyticsNotifierProvider.notifier).loadAll();
              await ref.read(stockAlertsNotifierProvider.notifier).loadAll();
              await ref.read(notificationsNotifierProvider.notifier).loadAll();
              await ref.read(auditLogsNotifierProvider.notifier).loadRecent();
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ---------------- ترحيب وزر نقطة البيع البارز بالأعلى ----------------
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.user != null ? 'مرحبًا بك، د. ${authState.user!.fullName} 👋' : 'مرحبًا بك في PharmaOS',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'نظام الصيدلية المتطور - نقطة البيع والمخزون والمحاسب الذكي والـ AI',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.point_of_sale, size: 22),
                        label: const Text('فتح نقطة البيع السريعة (POS)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => context.go('/pos'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ---------------- بطاقات الإحصائيات السريعة ----------------
                Row(
                  children: [
                    Expanded(
                      child: SummaryStatCard(
                        label: 'مبيعات الفترة الحالية',
                        value: preview != null ? '${preview.totalSales.toStringAsFixed(0)} ر.ي' : '0 ر.ي',
                        color: Colors.green,
                        icon: Icons.point_of_sale,
                        onTap: () => _navigate(context, const DailyClosingScreen()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SummaryStatCard(
                        label: 'صافي الأرباح',
                        value: preview != null ? '${preview.netProfit.toStringAsFixed(0)} ر.ي' : '0 ر.ي',
                        color: Colors.teal,
                        icon: Icons.trending_up,
                        onTap: () => _navigate(context, const DailyClosingScreen()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SummaryStatCard(
                        label: 'مدفوعات الموردين',
                        value: preview != null ? '${preview.totalVendorPayments.toStringAsFixed(0)} ر.ي' : '0 ر.ي',
                        color: Colors.blue,
                        icon: Icons.shopping_bag_outlined,
                        onTap: () => _navigate(context, const PurchasesScreen()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SummaryStatCard(
                        label: 'المصاريف',
                        value: preview != null ? '${preview.totalExpenses.toStringAsFixed(0)} ر.ي' : '0 ر.ي',
                        color: Colors.orange,
                        icon: Icons.money_off,
                        onTap: () => _navigate(context, const ExpensesScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ---------------- أقسام النظام المصنفة ----------------
                const DashboardSectionHeader(title: 'دليل الأدوية، المخزون، والشركات'),
                Wrap(children: [
                  DashboardNavButton(
                    icon: Icons.medication_outlined,
                    label: 'قائمة الأدوية الشاملة',
                    onTap: () => _navigate(context, const MedicinesScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.inventory_2_outlined,
                    label: 'مخزون الصيدلية المتوفر',
                    onTap: () => _navigate(context, const InventoryScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.fact_check_outlined,
                    label: 'التسوية الجردية',
                    onTap: () => _navigate(context, const InventoryReconciliationScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.face_retouching_natural,
                    label: 'تجميل وحفاضات',
                    onTap: () => _navigate(context, const MedicinesScreen(filter: MedicinesFilter.cosmeticsAndDiapers)),
                  ),
                  DashboardNavButton(
                    icon: Icons.warning_amber_rounded,
                    label: 'نواقص الأدوية',
                    onTap: () => _navigate(context, const MedicinesScreen(filter: MedicinesFilter.incomplete)),
                  ),
                  DashboardNavButton(
                    icon: Icons.add_alert_outlined,
                    label: 'النواقص وطلبات العملاء',
                    onTap: () => _navigate(context, const WantedMedicinesScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.category_outlined,
                    label: 'التصنيفات الدوائية',
                    onTap: () => _navigate(context, const CategoriesScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.business_center_outlined,
                    label: 'الشركات المتعامل معها',
                    onTap: () => _navigate(context, const ActiveCompaniesScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.factory_outlined,
                    label: 'دليل الشركات العام',
                    onTap: () => _navigate(context, const CompaniesScreen()),
                  ),
                ]),
                const SizedBox(height: 16),

                // ---------------- أقسام الإدارة الطبية والربط السحابي ----------------
                const DashboardSectionHeader(title: 'الربط السحابي، تطبيق المدير، وغرفة الروشتات (Tele-Pharmacy)'),
                Wrap(children: [
                  DashboardNavButton(
                    icon: Icons.wifi_channel_rounded,
                    label: 'غرفة الروشتات والاستشارات',
                    onTap: () => TeleConsultationDialog.show(context),
                  ),
                  DashboardNavButton(
                    icon: Icons.phone_android_rounded,
                    label: 'بوابة وتطبيق المدير السحابي',
                    onTap: () => _navigate(context, const OwnerPortalScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.receipt_long,
                    label: 'الوصفات الطبية (Prescriptions)',
                    onTap: () => _navigate(context, const PrescriptionsScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.medical_services,
                    label: 'أطباء وعيادات',
                    onTap: () => _navigate(context, const DoctorsScreen()),
                  ),
                ]),
                const SizedBox(height: 16),

                const DashboardSectionHeader(title: 'المشتريات والموردون وديون الصيدلية'),
                Wrap(children: [
                  DashboardNavButton(
                    icon: Icons.person_search_outlined,
                    label: 'البحث عن مورد الدواء',
                    onTap: () => _navigate(context, const MedicineSupplierFinderScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.handshake_outlined,
                    label: 'الموردون المتعامل معهم',
                    onTap: () => _navigate(context, const ActiveSuppliersScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.local_shipping_outlined,
                    label: 'دليل الموردين العام',
                    onTap: () => _navigate(context, const SuppliersScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.shopping_cart_checkout,
                    label: 'فواتير المشتريات والتوريد',
                    onTap: () => _navigate(context, const PurchasesScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.money_off_csred_outlined,
                    label: 'ديون الصيدلية (المحاسب الذكي)',
                    onTap: () => _navigate(context, const PharmacyDebtsScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.payment_outlined,
                    label: 'سداد دفعات الموردين',
                    onTap: () => _navigate(context, const VendorPaymentsScreen()),
                  ),
                ]),

                const DashboardSectionHeader(title: 'المالية، المصاريف، وإغلاق اليومية'),
                Wrap(children: [
                  DashboardNavButton(
                    icon: Icons.receipt_long_outlined,
                    label: 'الفواتير الشاملة',
                    onTap: () => _navigate(context, const InvoicesScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.people_outline,
                    label: 'سجل العملاء والديون',
                    onTap: () => _navigate(context, const CustomersScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.money_off_outlined,
                    label: 'مصاريف الصيدلية',
                    onTap: () => _navigate(context, const ExpensesScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.lock_clock_outlined,
                    label: 'إغلاق اليومية والنوبات',
                    onTap: () => _navigate(context, const DailyClosingScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.badge_outlined,
                    label: 'كادر العمل والرواتب',
                    onTap: () => _navigate(context, const WorkersScreen()),
                  ),
                ]),

                const DashboardSectionHeader(title: 'التقارير، التنبيهات، والذكاء الاصطناعي'),
                Wrap(children: [
                  DashboardNavButton(
                    icon: Icons.analytics_outlined,
                    label: 'التقارير الشاملة والأرباح',
                    onTap: () => _navigate(context, const ReportsScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.query_stats_outlined,
                    label: 'تحليلات الأداء والرسوم',
                    onTap: () => _navigate(context, const AnalyticsScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.auto_awesome,
                    label: 'المساعد الصيدلاني الذكي (AI)',
                    onTap: () => FloatingAiDialog.show(context),
                  ),
                  DashboardNavButton(
                    icon: Icons.notifications_active_outlined,
                    label: 'تنبيهات الصلاحية والنواقص',
                    onTap: () => _navigate(context, const StockAlertsScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.history_edu_outlined,
                    label: 'سجل العمليات والرقابة',
                    onTap: () => _navigate(context, const AuditLogsScreen()),
                  ),
                ]),

                const DashboardSectionHeader(title: 'الإعدادات، الأمان، وإدارة النظام'),
                Wrap(children: [
                  DashboardNavButton(
                    icon: Icons.dashboard_customize_outlined,
                    label: 'لوحة التحكم وتخصيص الأقسام',
                    onTap: () => _navigate(context, const DashboardLayoutManagerScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.settings_outlined,
                    label: 'إعدادات الصيدلية',
                    onTap: () => _navigate(context, const SettingsScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.manage_accounts_outlined,
                    label: 'المستخدمون والصلاحيات',
                    onTap: () => _navigate(context, const UsersScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.security_outlined,
                    label: 'مصفوفة الصلاحيات',
                    onTap: () => _navigate(context, const PermissionsScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.print_outlined,
                    label: 'الطابعات والأجهزة والباركود',
                    onTap: () => _navigate(context, const HardwareManagementScreen()),
                  ),
                  DashboardNavButton(
                    icon: Icons.cloud_sync_outlined,
                    label: 'النسخ الاحتياطي والحماية',
                    onTap: () => _navigate(context, const BackupScreen()),
                  ),
                ]),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Text(
                          'PharmaOS - نظام إدارة الصيدليات الشامل والمتكامل',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'تطوير وهندسة برمجية: ',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              'م/عباد السويدي',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(width: 14),
                            Icon(Icons.phone_android, size: 14, color: Colors.teal),
                            SizedBox(width: 4),
                            SelectableText(
                              '+967776065503',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
  }
}
