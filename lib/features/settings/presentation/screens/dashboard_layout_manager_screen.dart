// شاشة إدارة أقسام لوحة التحكم وتخصيص النظام - PharmaOS
// تتيح للصيدلي التحكم الكامل في إظهار، إخفاء، وترتيب كافة أقسام وشاشات النظام
// بدون الحاجة لأي مبرمج أو تعديل في الكود.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'section_inspector_screen.dart';

class DashboardModuleItem {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  bool isEnabled;

  DashboardModuleItem({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isEnabled = true,
  });
}

class DashboardLayoutManagerScreen extends ConsumerStatefulWidget {
  const DashboardLayoutManagerScreen({super.key});

  @override
  ConsumerState<DashboardLayoutManagerScreen> createState() => _DashboardLayoutManagerScreenState();
}

class _DashboardLayoutManagerScreenState extends ConsumerState<DashboardLayoutManagerScreen> {
  late List<DashboardModuleItem> _modules;
  bool _isInitialized = false;

  final List<DashboardModuleItem> _defaultModules = [
    DashboardModuleItem(
      key: 'pos',
      title: 'نقطة البيع السريعة (POS)',
      description: 'شاشة البيع وقراءة الباركود والدفع المتعدد',
      icon: Icons.point_of_sale,
      color: Colors.green,
    ),
    DashboardModuleItem(
      key: 'medicines',
      title: 'دليل الأدوية الشامل (33,600+ دواء)',
      description: 'كتالوج الأدوية اليمني والترقيم والباركود والبدائل',
      icon: Icons.medication_outlined,
      color: Colors.teal,
    ),
    DashboardModuleItem(
      key: 'inventory',
      title: 'مخزون الصيدلية الفعلي',
      description: 'إدخال البضاعة بالحساب الهرمي (كرتون/باكت/شريط/حبة) وجرد المخزون',
      icon: Icons.inventory_2_outlined,
      color: Colors.indigo,
    ),
    DashboardModuleItem(
      key: 'invoices',
      title: 'الفواتير الشاملة وتسميتها',
      description: 'فواتير المبيعات والمشتريات والبحث متعدد الحقول والطباعة',
      icon: Icons.receipt_long,
      color: Colors.blue,
    ),
    DashboardModuleItem(
      key: 'customers',
      title: 'سجل العملاء والديون',
      description: 'كشوف حسابات العملاء ومتابعة ديونهم وتسديدها',
      icon: Icons.people_outline,
      color: Colors.purple,
    ),
    DashboardModuleItem(
      key: 'active_suppliers',
      title: 'الموردون المتعامل معهم',
      description: 'قائمة الشركاء والموردين الفعليين وإدارة التوريدات',
      icon: Icons.handshake_outlined,
      color: Colors.teal,
    ),
    DashboardModuleItem(
      key: 'active_companies',
      title: 'الشركات المتعامل معها',
      description: 'قائمة الشركات المصنعة التي تتوفر أدويتها بالصيدلية',
      icon: Icons.business_center_outlined,
      color: Colors.indigo,
    ),
    DashboardModuleItem(
      key: 'pharmacy_debts',
      title: 'كشف ديون الصيدلية (المحاسب الذكي)',
      description: 'رصد ديون الصيدلية للموردين وسندات الصرف الفورية',
      icon: Icons.account_balance_wallet_outlined,
      color: Colors.red,
    ),
    DashboardModuleItem(
      key: 'suppliers',
      title: 'دليل الموردين والوكالات العام',
      description: 'دليل كافة الوكالات والشركات الموردة في السوق اليمني',
      icon: Icons.business,
      color: Colors.cyan,
    ),
    DashboardModuleItem(
      key: 'purchases',
      title: 'فواتير المشتريات والتوريد',
      description: 'تسجيل بوالص التوريد ودفعات الموردين',
      icon: Icons.shopping_cart_outlined,
      color: Colors.orange,
    ),
    DashboardModuleItem(
      key: 'expenses',
      title: 'المصاريف وسحبيات العمال',
      description: 'إدارة المصروفات اليومية والشهرية وسلفيات الموظفين',
      icon: Icons.money_off,
      color: Colors.amber,
    ),
    DashboardModuleItem(
      key: 'daily_closing',
      title: 'إغلاق اليومية (Daily Closing)',
      description: 'حساب الأرباح الفعلية والمبيعات وتصدير التقرير PDF/Excel',
      icon: Icons.lock_clock,
      color: Colors.deepOrange,
    ),
    DashboardModuleItem(
      key: 'workers',
      title: 'إدارة عمال وموظفي الصيدلية',
      description: 'كشوف الحسابات والرواتب والسحبيات لكل موظف',
      icon: Icons.badge_outlined,
      color: Colors.blueGrey,
    ),
    DashboardModuleItem(
      key: 'returns',
      title: 'مرتجعات المبيعات والمشتريات',
      description: 'معالجة المرتجعات واسترداد المبالغ وضبط المخزون',
      icon: Icons.replay,
      color: Colors.brown,
    ),
    DashboardModuleItem(
      key: 'wallets',
      title: 'المحافظ الإلكترونية والصناديق',
      description: 'إدارة محافظ الدفع (جيب، جوالي، ون كاش، الكريمي...)',
      icon: Icons.account_balance,
      color: Colors.lightGreen,
    ),
    DashboardModuleItem(
      key: 'ai',
      title: 'المساعد الصيدلاني الذكي (AI)',
      description: 'الذكاء الاصطناعي للتفاعلات الدوائية والاستشارات',
      icon: Icons.smart_toy_outlined,
      color: Colors.deepPurple,
    ),
    DashboardModuleItem(
      key: 'analytics',
      title: 'التحليلات والمؤشرات المالية',
      description: 'إحصائيات الأدوية الأكثر مبيعاً والأرباح وحركة الأصناف',
      icon: Icons.analytics_outlined,
      color: Colors.teal,
    ),
    DashboardModuleItem(
      key: 'backup',
      title: 'النسخ الاحتياطي والأمان',
      description: 'إنشاء نسخ احتياطية لقاعدة البيانات واستعادتها بأمان',
      icon: Icons.backup_outlined,
      color: Colors.blueGrey,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final disabled = ref.read(settingsNotifierProvider).settings.disabledModules;
      _modules = _defaultModules.map((m) {
        m.isEnabled = !disabled.contains(m.key);
        return m;
      }).toList();
      _isInitialized = true;
    }
  }

  Future<void> _saveLayout() async {
    final currentSettings = ref.read(settingsNotifierProvider).settings;
    final disabledKeys = _modules.where((m) => !m.isEnabled).map((m) => m.key).toList();

    final updated = currentSettings.copyWith(
      disabledModules: disabledKeys,
    );

    await ref.read(settingsNotifierProvider.notifier).save(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ تخصيصات لوحة التحكم وتحديث الواجهة بنجاح ✓'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('إدارة أقسام لوحة التحكم وتخصيص النظام'),
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('حفظ التعديلات'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _saveLayout,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            // بطاقة التوجيه والتعليمات
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.tune, color: Colors.teal),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('لوحة التحكم الديناميكية التفاعلية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text(
                          'يمكنك تفعيل أو إخفاء أي قسم بالنظام، وترتيب الأقسام بالسحب والإفلات وفق ما يناسب عمل صيدليتك تماماً.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // قائمة الأقسام القابلة لإعادة الترتيب
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _modules.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _modules.removeAt(oldIndex);
                    _modules.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final module = _modules[index];
                  return Card(
                    key: ValueKey(module.key),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drag_indicator, color: Colors.grey),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            backgroundColor: module.color.withOpacity(0.12),
                            child: Icon(module.icon, color: module.color),
                          ),
                        ],
                      ),
                      title: Text(
                        module.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: module.isEnabled ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        module.description,
                        style: TextStyle(fontSize: 12, color: module.isEnabled ? Colors.blueGrey : Colors.grey.shade400),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings_suggest_outlined, color: Colors.teal),
                            tooltip: 'التحكم وتخصيص تفاصيل وميزات القسم بدون برمجة',
                            onPressed: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SectionInspectorScreen(
                                    sectionKey: module.key,
                                    sectionTitle: module.title,
                                    sectionDescription: module.description,
                                    sectionIcon: module.icon,
                                    sectionColor: module.color,
                                  ),
                                ),
                              );
                              if (updated == true) {
                                setState(() {});
                              }
                            },
                          ),
                          Switch.adaptive(
                            value: module.isEnabled,
                            activeColor: Colors.teal,
                            onChanged: (val) {
                              setState(() {
                                module.isEnabled = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
