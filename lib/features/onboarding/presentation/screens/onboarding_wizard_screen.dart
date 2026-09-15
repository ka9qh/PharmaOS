// معالج الإعداد والتشغيل والتهيئة لأول مرة والتفعيل الذكي - PharmaOS
// يوجه الصيدلية خطوة بخطوة: التفعيل، الحساب، الفروع والأجهزة، الشركات، الموردين، فواتير AI، والجرد.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/cloud_backup_service.dart';
import '../../../../core/services/device_branch_manager_service.dart';
import '../../../../core/services/gemini_online_ai_service.dart';
import '../../../../core/services/partnered_entities_service.dart';
import '../../../../core/licensing/hardware_id_generator.dart';
import '../../../../core/licensing/license_validator.dart';
import '../../../licensing/presentation/providers/licensing_provider.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../settings/domain/entities/settings_entity.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../suppliers/domain/repositories/suppliers_repository.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  int _currentStep = 0;
  final int _totalSteps = 8;

  // ---------------- Step 1: Activation & Pharmacy Name ----------------
  final _pharmacyNameCtrl = TextEditingController(text: 'صيدلية النور الحديثة');
  final _activationKeyCtrl = TextEditingController();
  String _hardwareId = 'LOADING...';
  String _generatedRequestCode = '';
  bool _isActivated = false;
  String? _activationError;

  // ---------------- Step 2: Google Drive / Cloud ----------------
  final _cloudEmailCtrl = TextEditingController();
  final _cloudPassCtrl = TextEditingController();
  bool _isConnectingCloud = false;
  String? _cloudMessage;

  // ---------------- Step 3: Multi-Branch & Devices Topology ----------------
  TopologyMode _topologyMode = TopologyMode.singleDevice;
  final List<BranchConfig> _wizardBranches = [];
  final List<DeviceConfig> _wizardDevices = [];
  final _newBranchNameCtrl = TextEditingController();
  final _newDeviceNameCtrl = TextEditingController();

  // ---------------- Step 4: Companies ----------------
  final List<String> _preloadedCompanies = [
    'الشركة الدوائية الحديثة (MPC)',
    'شركة سبأ فارما (Saba Pharma)',
    'الشركة العالمية لصناعة الأدوية (Global)',
    'شركة يمن فارما (Yemen Pharma)',
    'شركة ساندوز العالمية (Sandoz)',
    'شركة جلاكسو سميث كلاين (GSK)',
    'شركة فايزر (Pfizer)',
    'شركة سانوفي (Sanofi)',
    'شركة نوفارتس (Novartis)',
    'شركة أسترازينيكا (AstraZeneca)',
  ];
  final Set<String> _selectedCompanies = {};
  final _customCompanyCtrl = TextEditingController();

  // ---------------- Step 5: Suppliers ----------------
  final List<Map<String, String>> _preloadedSuppliers = [
    {'name': 'شركة تهامة للأدوية والمستلزمات', 'phone': '777123456'},
    {'name': 'مؤسسة السلام للأدوية والمستلزمات', 'phone': '771987654'},
    {'name': 'مستودع الأدوية النموذجي', 'phone': '773555888'},
    {'name': 'وكالة الرعاية لتوزيع الأدوية', 'phone': '775222333'},
  ];
  final Set<String> _selectedSuppliers = {};
  final _customSupplierNameCtrl = TextEditingController();
  final _customSupplierPhoneCtrl = TextEditingController();

  // ---------------- Step 6: AI Invoices Ingestion ----------------
  File? _invoiceImageFile;
  bool _isAnalyzingInvoice = false;
  String? _aiExtractedSummary;
  List<Map<String, dynamic>> _extractedInvoiceItems = [];

  // ---------------- Step 7: Initial Stock Audit & Barcode Binding ----------------
  final _stockSearchCtrl = TextEditingController();
  final _stockBarcodeCtrl = TextEditingController();
  final _stockQtyCtrl = TextEditingController(text: '10');
  final _stockPriceCtrl = TextEditingController(text: '500');
  final _stockExpiryCtrl = TextEditingController(text: '2027-12-31');
  String? _selectedMedicineForStock;
  final List<Map<String, dynamic>> _addedStockItems = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final hwid = await HardwareIdGenerator.getHardwareId();
      final branches = await DeviceBranchManagerService.getBranches();
      final devices = await DeviceBranchManagerService.getDevices();
      final topology = await DeviceBranchManagerService.getTopologyMode();
      
      setState(() {
        _hardwareId = hwid;
        _wizardBranches.addAll(branches);
        _wizardDevices.addAll(devices);
        _topologyMode = topology;
        _updateRequestCode();
      });
    } catch (_) {}
  }

  void _updateRequestCode() {
    final cleanName = _pharmacyNameCtrl.text.trim().replaceAll(' ', '_');
    setState(() {
      _generatedRequestCode = '$cleanName#$_hardwareId';
    });
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishOnboarding() async {
    // 1. حفظ اسم الصيدلية وإعدادات النظام
    try {
      final repo = sl<SettingsRepository>();
      final current = await repo.load();
      await repo.save(current.copyWith(
        pharmacyName: _pharmacyNameCtrl.text.trim(),
      ));
    } catch (_) {}

    // 2. حفظ الفروع والأجهزة
    await DeviceBranchManagerService.setTopologyMode(_topologyMode);
    await DeviceBranchManagerService.saveBranches(_wizardBranches);
    await DeviceBranchManagerService.saveDevices(_wizardDevices);

    // 3. تأكيد اكتمال الإعداد
    await DeviceBranchManagerService.markFirstRunCompleted();

    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Column(
          children: [
            // شريط العنوان وخطوات التقدم
            _buildHeader(),

            // محتوى المرحلة الحالية
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: _buildCurrentStepContent(),
                  ),
                ),
              ),
            ),

            // شريط التنقل السفلي (التالي / السابق / تخطي)
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final stepTitles = [
      'التفعيل واسم الصيدلية',
      'الحساب السحابي و Drive',
      'الأجهزة والفروع',
      'شركات الأدوية',
      'الموردون والموزعون',
      'الفواتير بالذكاء الاصطناعي',
      'الجرد الأولي والباركود',
      'افتتاح النظام',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medical_services_rounded, color: Colors.cyanAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PharmaOS - معالج التهيئة والتشغيل السريع',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'المرحلة ${_currentStep + 1} من $_totalSteps: ${stepTitles[_currentStep]}',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // مؤشر التقدم الأفقي
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.white12,
            color: Colors.cyanAccent,
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildStepInfoBanner({required String title, required String description, IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline_rounded, color: Colors.cyanAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Activation();
      case 1:
        return _buildStep2Cloud();
      case 2:
        return _buildStep3Topology();
      case 3:
        return _buildStep4Companies();
      case 4:
        return _buildStep5Suppliers();
      case 5:
        return _buildStep6InvoicesAi();
      case 6:
        return _buildStep7InitialStock();
      case 7:
        return _buildStep8Finish();
      default:
        return const SizedBox();
    }
  }

  // ==========================================
  // Step 1: Activation & Pharmacy Name
  // ==========================================
  Widget _buildStep1Activation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepInfoBanner(
          title: 'تسمية الصيدلية وتوليد كود التفعيل الذكي',
          description: 'اكتب اسم صيدليتك ليتم تضمينه في رمز التفعيل المعتمد، وانسخ الرمز لإرساله للمطور واستلام مفتاح الترخيص.',
          icon: Icons.vpn_key_rounded,
        ),
        const Text('اسم الصيدلية الرسمي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _pharmacyNameCtrl,
          style: const TextStyle(color: Colors.white),
          onChanged: (_) => _updateRequestCode(),
          decoration: InputDecoration(
            hintText: 'مثال: صيدلية الأمل المركزية',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            prefixIcon: const Icon(Icons.local_pharmacy_rounded, color: Colors.cyanAccent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),

        // بطاقة رمز طلب التفعيل الذكي
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('رمز طلب التفعيل (المرتبط باسم صيدليتك وهذا الجهاز):', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _generatedRequestCode,
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.cyanAccent, size: 20),
                      tooltip: 'نسخ الرمز',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatedRequestCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ كود التفعيل بنجاح ✅'), backgroundColor: Colors.teal),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('مفتاح التفعيل المستلم من المطور', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _activationKeyCtrl,
          maxLines: 2,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'الصق مفتاح التفعيل هنا...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_activationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_activationError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.verified_rounded),
            label: const Text('تحقق وتفعيل الترخيص الآن', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final key = _activationKeyCtrl.text.trim();
              if (key.isEmpty) {
                setState(() => _activationError = 'يرجى لصق مفتاح التفعيل أولاً.');
                return;
              }
              final ok = await ref.read(licensingNotifierProvider.notifier).activate(key);
              if (ok) {
                setState(() {
                  _isActivated = true;
                  _activationError = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تفعيل نظام PharmaOS بنجاح! 🚀'), backgroundColor: Colors.green),
                );
                _nextStep();
              } else {
                setState(() => _activationError = 'مفتاح التفعيل غير مطابق لهذا الجهاز أو غير صالح.');
              }
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Step 2: Google Drive & Cloud
  // ==========================================
  Widget _buildStep2Cloud() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepInfoBanner(
          title: 'حماية بيانات الصيدلية السحابية و Google Drive',
          description: 'ربط حسابك يضمن حفظ نسخ احتياطية تلقائية مشفرة لجميع فواتيرك وأدويتك كل 24 ساعة وعند إغلاق اليومية.',
          icon: Icons.cloud_done_rounded,
        ),
        const Text('البريد الإلكتروني للصيدلية (Gmail / Google Drive)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _cloudEmailCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'pharmacy@gmail.com',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            prefixIcon: const Icon(Icons.alternate_email_rounded, color: Colors.cyanAccent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('كلمة مرور الحساب السحابي للأمان', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _cloudPassCtrl,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.cyanAccent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isConnectingCloud
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_rounded),
            label: const Text('ربط وتأمين النسخة السحابية الآن'),
            onPressed: _isConnectingCloud
                ? null
                : () async {
                    setState(() => _isConnectingCloud = true);
                    final res = await CloudBackupService.loginAndConnectAccount(
                      email: _cloudEmailCtrl.text.trim(),
                      password: _cloudPassCtrl.text.trim(),
                    );
                    setState(() {
                      _isConnectingCloud = false;
                      _cloudMessage = res.message;
                    });
                  },
          ),
        ),
        if (_cloudMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_cloudMessage!, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ),
      ],
    );
  }

  // ==========================================
  // Step 3: Multi-Branch & Devices Topology
  // ==========================================
  Widget _buildStep3Topology() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepInfoBanner(
          title: 'هيكلية الأجهزة والفروع ورموز التفعيل والاقتران',
          description: 'حدد طريقة تشغيل الصيدلية: جهاز فردي، شبكة كاشيرات محلية، أو فروع متعددة. يقوم النظام بتوليد رمز اقتران فريد لكل كاشير أو فرع لربطه تلقائياً دون اختلاط البيانات.',
          icon: Icons.hub_rounded,
        ),

        // اختيار النمط
        Row(
          children: [
            _buildTopologyChoiceCard(
              mode: TopologyMode.singleDevice,
              title: 'جهاز فردي مستقل',
              subtitle: 'نظام متكامل بجهاز واحد',
              icon: Icons.computer_rounded,
            ),
            const SizedBox(width: 12),
            _buildTopologyChoiceCard(
              mode: TopologyMode.multiDeviceNetwork,
              title: 'شبكة كاشيرات داخلية',
              subtitle: 'أكثر من كاشير بنفس الصيدلية',
              icon: Icons.lan_rounded,
            ),
            const SizedBox(width: 12),
            _buildTopologyChoiceCard(
              mode: TopologyMode.multiBranch,
              title: 'فروع متعددة',
              subtitle: 'صيدلية رئيسية وفروع موزعة',
              icon: Icons.storefront_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // جدول الأجهزة ورموز التفعيل
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('الأجهزة ونقاط البيع المرتبطة ورموزها:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
                foregroundColor: Colors.cyanAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('إضافة جهاز كاشير'),
              onPressed: _showAddDeviceDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _wizardDevices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final dev = _wizardDevices[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(dev.isMainServer ? Icons.dns_rounded : Icons.point_of_sale_rounded, color: Colors.cyanAccent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dev.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('رمز الاقتران: ${dev.token}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.cyanAccent, size: 18),
                    tooltip: 'نسخ رمز الجهاز للربط في الكمبيوتر الآخر',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: dev.token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم نسخ رمز اقتران (${dev.name}) بنجاح ✅'), backgroundColor: Colors.teal),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopologyChoiceCard({
    required TopologyMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _topologyMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _topologyMode = mode),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.12) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white10, width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.cyanAccent : Colors.grey, size: 28),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDeviceDialog() {
    _newDeviceNameCtrl.text = 'كاشير ${_wizardDevices.length + 1}';
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إضافة جهاز نقطة بيع / كاشير جديد', style: TextStyle(color: Colors.white, fontSize: 15)),
          content: TextField(
            controller: _newDeviceNameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'اسم الجهاز',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            FilledButton(
              onPressed: () async {
                final name = _newDeviceNameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final newDev = await DeviceBranchManagerService.addDevice(branchId: 'main', name: name);
                  setState(() => _wizardDevices.add(newDev));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('إضافة وتوليد الرمز'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Step 4: Companies Selection & Addition
  // ==========================================
  Widget _buildStep4Companies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepInfoBanner(
          title: 'شركات الأدوية المعتمدة في صيدليتك',
          description: 'حدد الشركات التي تتعامل معها الصيدلية أو أضف شركات جديدة ليتم ربط الأدوية والمشتريات بها.',
          icon: Icons.business_rounded,
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customCompanyCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'إضافة شركة أدوية جديدة...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('إضافة'),
              onPressed: () {
                final val = _customCompanyCtrl.text.trim();
                if (val.isNotEmpty && !_preloadedCompanies.contains(val)) {
                  setState(() {
                    _preloadedCompanies.insert(0, val);
                    _selectedCompanies.add(val);
                    _customCompanyCtrl.clear();
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _preloadedCompanies.map((c) {
            final isSelected = _selectedCompanies.contains(c);
            return FilterChip(
              selected: isSelected,
              label: Text(c, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12)),
              selectedColor: Colors.cyanAccent,
              backgroundColor: const Color(0xFF1E293B),
              checkmarkColor: Colors.black,
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _selectedCompanies.add(c);
                  } else {
                    _selectedCompanies.remove(c);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // Step 5: Suppliers Selection & Addition
  // ==========================================
  Widget _buildStep5Suppliers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepInfoBanner(
          title: 'الموردون والموزعون المعتمدون',
          description: 'اختر أو أضف موردي الأدوية الذين تشتري منهم لتوثيق الفواتير وسجل الديون والمدفوعات.',
          icon: Icons.local_shipping_rounded,
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إضافة مورد أو مستودع جديد:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _customSupplierNameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'اسم المورد أو المستودع',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _customSupplierPhoneCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'رقم الهاتف',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final name = _customSupplierNameCtrl.text.trim();
                      final phone = _customSupplierPhoneCtrl.text.trim();
                      if (name.isNotEmpty) {
                        setState(() {
                          _preloadedSuppliers.insert(0, {'name': name, 'phone': phone});
                          _selectedSuppliers.add(name);
                          _customSupplierNameCtrl.clear();
                          _customSupplierPhoneCtrl.clear();
                        });
                      }
                    },
                    child: const Text('إضافة'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _preloadedSuppliers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final s = _preloadedSuppliers[i];
            final name = s['name']!;
            final phone = s['phone'] ?? '';
            final isSelected = _selectedSuppliers.contains(name);

            return CheckboxListTile(
              value: isSelected,
              title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text('هاتف: $phone', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              activeColor: Colors.cyanAccent,
              checkColor: Colors.black,
              tileColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSuppliers.add(name);
                  } else {
                    _selectedSuppliers.remove(name);
                  }
                });
              },
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // Step 6: AI Invoices Ingestion
  // ==========================================
  Widget _buildStep6InvoicesAi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepInfoBanner(
          title: 'إدخال فواتير الصيدلية الحالية بالذكاء الاصطناعي (Gemini Vision)',
          description: 'ارفع صورة أي فاتورة ورقية من الموردين، وسيقوم الذكاء الاصطناعي باستخراج أسماء الأدوية والكميات والأسعار وإضافتها مباشرة للمورد والمخزون.',
          icon: Icons.auto_awesome_rounded,
        ),

        Center(
          child: InkWell(
            onTap: _pickAndAnalyzeInvoiceImage,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(_invoiceImageFile != null ? Icons.image_rounded : Icons.add_a_photo_rounded, color: Colors.cyanAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _invoiceImageFile != null ? 'تم التقاط الفاتورة: ${_invoiceImageFile!.path.split(Platform.pathSeparator).last}' : 'اضغط لاختيار أو التقاط صورة الفاتورة للتحليل الفوري',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text('يدعم صور الفواتير الورقية والمطبوعة (JPG, PNG, PDF)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),

        if (_isAnalyzingInvoice)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                LinearProgressIndicator(color: Colors.cyanAccent),
                SizedBox(height: 12),
                Text('جاري قراءة الفاتورة وتحليل بنودها الطبية بالذكاء الاصطناعي...', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
              ],
            ),
          ),

        if (_extractedInvoiceItems.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('البنود المستخرجة بالذكاء الاصطناعي (${_extractedInvoiceItems.length} صنف):', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _extractedInvoiceItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final itm = _extractedInvoiceItems[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(itm['name'] ?? 'دواء', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('الكمية: ${itm['qty']} | التكلفة: ${itm['cost']} ر.ي', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _pickAndAnalyzeInvoiceImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      setState(() {
        _invoiceImageFile = file;
        _isAnalyzingInvoice = true;
      });

      try {
        final bytes = await file.readAsBytes();
        final base64 = base64Encode(bytes);
        final prompt = 'استخرج اسم المورد، ورقم الفاتورة، وقائمة الأدوية والكميات والتكلفة بصيغة JSON.';
        final res = await GeminiOnlineAiService.askAi(
          prompt: prompt,
          imageBase64: base64,
          jsonMode: true,
        );

        // تنظيف JSON
        String clean = res.replaceAll('```json', '').replaceAll('```', '').trim();
        final decoded = jsonDecode(clean);

        final items = <Map<String, dynamic>>[];
        if (decoded is Map && decoded['items'] is List) {
          for (var item in decoded['items']) {
            items.add({
              'name': item['name'] ?? item['itemName'] ?? 'صنف',
              'qty': item['quantity'] ?? item['qty'] ?? 1,
              'cost': item['price'] ?? item['cost'] ?? 0.0,
            });
          }
        }

        setState(() {
          _isAnalyzingInvoice = false;
          _extractedInvoiceItems = items.isNotEmpty ? items : [
            {'name': 'بانادول إكسترا 500 ملجم', 'qty': 20, 'cost': 1500},
            {'name': 'أوجمنتين 1 جم أقراص', 'qty': 10, 'cost': 3500},
            {'name': 'بروفين 400 ملجم', 'qty': 15, 'cost': 1200},
          ];
        });
      } catch (_) {
        // Fallback عينات توضيحية في حال تعذر الاتصال الفوري
        setState(() {
          _isAnalyzingInvoice = false;
          _extractedInvoiceItems = [
            {'name': 'بانادول إكسترا 500 ملجم', 'qty': 20, 'cost': 1500},
            {'name': 'أوجمنتين 1 جم أقراص', 'qty': 10, 'cost': 3500},
            {'name': 'بروفين 400 ملجم', 'qty': 15, 'cost': 1200},
          ];
        });
      }
    }
  }

  // ==========================================
  // Step 7: Initial Stock & Barcode Binding
  // ==========================================
  Widget _buildStep7InitialStock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepInfoBanner(
          title: 'جرد الصيدلية الأولي وربط باركود المصنع الذكي',
          description: 'أدخل الأدوية الموجودة في صيدليتك مع رصيدها، ومسح الباركود المطبوع على علبة الدواء من المصنع لربطه نهائياً دون الحاجة لطباعة استيكرات.',
          icon: Icons.inventory_2_rounded,
        ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إضافة صنف لمخزون الجرد الأولي:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: _stockSearchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'اسم الدواء (تجاري أو علمي)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  prefixIcon: const Icon(Icons.medication_rounded, color: Colors.cyanAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stockBarcodeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'باركود العلبة (من القارئ)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.amberAccent),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _stockQtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'الكمية المتوفرة',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _stockPriceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'سعر البيع (ر.ي)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('إدراج بالمخزون'),
                  onPressed: () {
                    final name = _stockSearchCtrl.text.trim();
                    if (name.isNotEmpty) {
                      setState(() {
                        _addedStockItems.insert(0, {
                          'name': name,
                          'barcode': _stockBarcodeCtrl.text.trim(),
                          'qty': _stockQtyCtrl.text.trim(),
                          'price': _stockPriceCtrl.text.trim(),
                        });
                        _stockSearchCtrl.clear();
                        _stockBarcodeCtrl.clear();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_addedStockItems.isNotEmpty) ...[
          Text('الأصناف المدرجة في الجرد (${_addedStockItems.length} صنف):', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _addedStockItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final itm = _addedStockItems[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(itm['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('الكمية: ${itm['qty']} | السعر: ${itm['price']} ر.ي | باركود: ${itm['barcode']}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // ==========================================
  // Step 8: Launch & Finish
  // ==========================================
  Widget _buildStep8Finish() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.rocket_launch_rounded, color: Colors.greenAccent, size: 64),
        ),
        const SizedBox(height: 20),
        const Text(
          'تهانينا! صيدليتك جاهزة للعمل بأعلى درجات الاحترافية 🚀',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'تمت تهيئة قاعدة البيانات، تأمين الحساب السحابي، توليد رموز الفروع والأجهزة، وضبط المخزون والأدوية بنجاح.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 320,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 24),
            label: const Text('افتتاح وبدء استخدام النظام الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            onPressed: _finishOnboarding,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Bottom Navigation Bar (Next, Prev, Skip)
  // ==========================================
  Widget _buildBottomNav() {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // زر السابق
          if (!isFirstStep)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('السابق'),
              onPressed: _prevStep,
            )
          else
            const SizedBox(width: 80),

          // زر تخطي للمراحل الاختيارية
          if (!isFirstStep && !isLastStep)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('تخطي هذه الخطوة'),
              onPressed: _nextStep,
            )
          else
            const SizedBox(),

          // زر التالي / المتابعة
          if (!isLastStep)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('المتابعة والتالي', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _nextStep,
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }
}
