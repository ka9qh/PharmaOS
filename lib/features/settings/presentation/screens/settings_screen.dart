// شاشة الإعدادات - PharmaOS
// ⚠️ ملاحظة صادقة: اسم الصيدلية والعملة يُحفظان فعليًا ويُستخدمان في تقارير
// إغلاق النوبة (PDF/Excel). لكن استبدال النص الثابت "ريال" في بقية شاشات
// النظام (POS، المخزون، إلخ) بقيمة العملة هذه لم يُنفَّذ بعد بالكامل -
// راجع core/utils/currency_formatter.dart للتفاصيل.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../controllers/settings_controller.dart';
import '../widgets/settings_widget.dart';
import '../../domain/entities/settings_entity.dart';
import 'dashboard_layout_manager_screen.dart';
import 'medicine_import_screen.dart';
import '../../../hardware/presentation/screens/hardware_management_screen.dart';
import '../../../../core/services/screenshot_service.dart';
import '../../../../core/services/ai_floating_settings_service.dart';
import '../widgets/update_checker_card.dart';
import '../widgets/cloud_sync_card.dart';
import '../widgets/secure_activation_tokens_card.dart';
import 'devices_branches_management_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currencyController = TextEditingController();
  final _reorderController = TextEditingController();
  final _savePathController = TextEditingController();
  String _saveFormat = 'PDF';
  bool _isMultiCurrencyEnabled = false;
  bool _isNotificationsEnabled = true;
  bool _deductAbsenceFromSalary = false;
  final _absenceDeductionController = TextEditingController();
  
  bool _taxEnabled = false;
  final _taxRateController = TextEditingController();
  
  bool _initialized = false;
  String? _nameError, _reorderError;

  void _syncControllers(PharmacySettings settings) {
    if (_initialized) return;
    _nameController.text = settings.pharmacyName;
    _phoneController.text = settings.pharmacyPhone;
    _currencyController.text = settings.currencyLabel;
    _reorderController.text = settings.defaultReorderLevel.toString();
    _savePathController.text = settings.savePath;
    _saveFormat = settings.saveFormat;
    _isMultiCurrencyEnabled = settings.isMultiCurrencyEnabled;
    _isNotificationsEnabled = settings.isNotificationsEnabled;
    _deductAbsenceFromSalary = settings.deductAbsenceFromSalary;
    _absenceDeductionController.text = settings.absenceDeductionAmount.toString();
    _taxEnabled = settings.taxEnabled;
    _taxRateController.text = settings.taxRate.toString();
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currencyController.dispose();
    _reorderController.dispose();
    _savePathController.dispose();
    _absenceDeductionController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameError = SettingsController.validatePharmacyName(_nameController.text);
    final reorderError = SettingsController.validateReorderLevel(_reorderController.text);
    setState(() {
      _nameError = nameError;
      _reorderError = reorderError;
    });
    if (nameError != null || reorderError != null) return;

    await ref.read(settingsNotifierProvider.notifier).save(
          PharmacySettings(
            pharmacyName: _nameController.text.trim(),
            pharmacyPhone: _phoneController.text.trim(),
            currencyLabel:
                _currencyController.text.trim().isEmpty ? 'ريال' : _currencyController.text.trim(),
            defaultReorderLevel: int.parse(_reorderController.text),
            savePath: _savePathController.text.trim(),
            saveFormat: _saveFormat,
            isMultiCurrencyEnabled: _isMultiCurrencyEnabled,
            isNotificationsEnabled: _isNotificationsEnabled,
            deductAbsenceFromSalary: _deductAbsenceFromSalary,
            absenceDeductionAmount: double.tryParse(_absenceDeductionController.text) ?? 0.0,
            taxEnabled: _taxEnabled,
            taxRate: double.tryParse(_taxRateController.text) ?? 15.0,
            disabledModules: ref.read(settingsNotifierProvider).settings.disabledModules,
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsNotifierProvider);
    _syncControllers(state.settings);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const UpdateCheckerCard(),
                  const CloudSyncCard(),
                  const SecureActivationTokensCard(),
                  Card(
                    color: Colors.teal.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.teal.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.teal.shade100, shape: BoxShape.circle),
                        child: const Icon(Icons.dashboard_customize, color: Colors.teal, size: 28),
                      ),
                      title: const Text(
                        'لوحة التحكم وإدارة الأقسام وتخصيص النظام',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: const Text(
                        'التحكم الكامل في إظهار أو إخفاء أي قسم، وترتيب الأقسام بالسحب والإفلات وفق طبيعة عمل صيدليتك دون الحاجة لأي مبرمج.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                      trailing: FilledButton.icon(
                        icon: const Icon(Icons.tune),
                        label: const Text('تخصيص الأقسام'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DashboardLayoutManagerScreen()),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: 'بيانات الصيدلية',
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(labelText: 'اسم الصيدلية', errorText: _nameError),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'رقم التواصل (اختياري)'),
                      ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'إعدادات عامة',
                    children: [
                      TextField(
                        controller: _currencyController,
                        decoration: const InputDecoration(
                          labelText: 'رمز العملة',
                          helperText: 'يُستخدم في تقارير إغلاق النوبة (PDF/Excel) حاليًا',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reorderController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'حد التنبيه الافتراضي للأدوية الجديدة',
                          errorText: _reorderError,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('دعم تعدد العملات'),
                        subtitle: const Text('تفعيل استخدام أكثر من عملة في النظام'),
                        value: _isMultiCurrencyEnabled,
                        onChanged: (val) => setState(() => _isMultiCurrencyEnabled = val),
                      ),
                      SwitchListTile(
                        title: const Text('تفعيل إشعارات النظام'),
                        value: _isNotificationsEnabled,
                        onChanged: (val) => setState(() => _isNotificationsEnabled = val),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('تفعيل الضرائب على المبيعات والمشتريات'),
                        value: _taxEnabled,
                        onChanged: (val) => setState(() => _taxEnabled = val),
                      ),
                      if (_taxEnabled)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: TextField(
                            controller: _taxRateController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'نسبة الضريبة المضافة (%)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('خصم الغياب من الراتب الأساسي'),
                        subtitle: const Text('عند التفعيل، سيتم خصم مبلغ محدد عن كل يوم غياب للموظف.'),
                        value: _deductAbsenceFromSalary,
                        onChanged: (val) => setState(() => _deductAbsenceFromSalary = val),
                      ),
                      if (_deductAbsenceFromSalary)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: TextField(
                            controller: _absenceDeductionController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'مبلغ الخصم لليوم الواحد',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'إعدادات الملفات والتقارير',
                    children: [
                      TextField(
                        controller: _savePathController,
                        decoration: const InputDecoration(
                          labelText: 'مسار حفظ الملفات الافتراضي (التقارير، الفواتير)',
                          helperText: 'مثال: C:\\PharmaOS_Files',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _saveFormat,
                        decoration: const InputDecoration(labelText: 'صيغة الحفظ الافتراضية'),
                        items: const [
                          DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                          DropdownMenuItem(value: 'Excel', child: Text('Excel')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _saveFormat = val);
                          }
                        },
                      ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'تخصيص لوحة التحكم',
                    children: [
                      const Text('يمكنك إخفاء الأقسام غير المستخدمة لتبسيط واجهة النظام:'),
                      const SizedBox(height: 8),
                      ..._buildModulesSwitches(state.settings.disabledModules, ref),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'بيانات الأدوية',
                    children: [
                      const Text(
                        'استورد قائمة أدوية دفعة واحدة من ملف Excel (فاتورة أو كتالوج من مورّدك) '
                        'بدل إدخال كل صنف يدويًا.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MedicineImportScreen()),
                        ),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('استيراد الأدوية من Excel'),
                      ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'الطابعات الحرارية والباركود وقارئ الباركود',
                    children: [
                      const Text(
                        'تحديد مقاسات الورق الحراري (80mm/58mm)، تخصيص لاصقات الباركود (صافي أو بالأسعار)، وفحص قارئ الباركود.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('فتح استوديو إعدادات الطابعات والباركود والأجهزة'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HardwareManagementScreen()),
                        ),
                      ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'إدارة بنية الأجهزة والفروع ورموز الاقتران',
                    children: [
                      const Text(
                        'تحديد نمط تشغيل المنظومة (جهاز مستقل / شبكة كاشيرات / فروع متعددة)، وإدارة وتوليد رموز الاقتران لنقاط البيع.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.hub_rounded),
                        label: const Text('فتح استوديو إدارة الأجهزة ونقاط البيع والفروع'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DevicesBranchesManagementScreen()),
                        ),
                      ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'مكان ظهور الزر العائم للذكاء الاصطناعي (AI Copilot)',
                    children: [
                      const Text(
                        'حدد الشاشات والواجهات التي يظهر فيها الزر العائم للمساعد الصيدلاني الذكي:',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<String>(
                        valueListenable: AiFloatingSettingsService.locationNotifier,
                        builder: (context, currentLoc, _) {
                          return Column(
                            children: [
                              RadioListTile<String>(
                                title: const Text('يظهر فقط في شاشة المبيعات (نقطة البيع POS) ⭐'),
                                subtitle: const Text('لمساعدة الكاشير أثناء البيع مع بقاء بقية الواجهات نظيفة'),
                                value: 'pos_only',
                                groupValue: currentLoc,
                                onChanged: (val) => AiFloatingSettingsService.setLocation(val!),
                              ),
                              RadioListTile<String>(
                                title: const Text('يظهر في جميع واجهات النظام والشاشات'),
                                subtitle: const Text('متاح دائماً في الزاوية في كافة الأقسام'),
                                value: 'all',
                                groupValue: currentLoc,
                                onChanged: (val) => AiFloatingSettingsService.setLocation(val!),
                              ),
                              RadioListTile<String>(
                                title: const Text('إخفاء الزر العائم (الوصول من لوحة التحكم فقط)'),
                                value: 'hidden',
                                groupValue: currentLoc,
                                onChanged: (val) => AiFloatingSettingsService.setLocation(val!),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'التقاط وتصوير الشاشة (Screenshots)',
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: ScreenshotService.floatingButtonNotifier,
                        builder: (context, isEnabled, _) {
                          return SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('إظهار زر التقاط الشاشة العائم 📸'),
                            subtitle: const Text('زر صغير عائم في الزاوية لتصوير أي شاشة وحفظها على سطح المكتب'),
                            value: isEnabled,
                            onChanged: (val) async {
                              await ScreenshotService.setFloatingButtonEnabled(val);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.keyboard_outlined, color: Colors.teal),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'اختصار لوحة المفاتيح الفوري: اضغط على F9 أو (Ctrl + Shift + S) من أي مكان في النظام لالتقاط الشاشة فوراً.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: state.isSaving ? null : _save,
                      child: state.isSaving
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('حفظ'),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 24, bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          'تطوير وهندسة برمجية بواسطة:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'م/عباد السويدي',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone, size: 16, color: Colors.teal),
                            SizedBox(width: 6),
                            SelectableText(
                              '+967776065503',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildModulesSwitches(List<String> disabledModules, WidgetRef ref) {
    final modules = {
      'customers': 'العملاء',
      'returns': 'المرتجعات',
      'expenses': 'المصاريف',
      'debts': 'قائمة الديون',
      'vendor_payments': 'تسديدات الموردين',
    };
    
    return modules.entries.map((e) {
      final isEnabled = !disabledModules.contains(e.key);
      return SwitchListTile(
        title: Text(e.value),
        value: isEnabled,
        onChanged: (val) {
          final newDisabled = List<String>.from(disabledModules);
          if (val) {
            newDisabled.remove(e.key);
          } else {
            newDisabled.add(e.key);
          }
          final newSettings = ref.read(settingsNotifierProvider).settings.copyWith(disabledModules: newDisabled);
          ref.read(settingsNotifierProvider.notifier).save(newSettings);
        },
      );
    }).toList();
  }
}
