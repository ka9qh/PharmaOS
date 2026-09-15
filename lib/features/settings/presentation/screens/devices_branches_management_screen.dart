// شاشة إدارة الأجهزة ونقاط البيع والفروع - PharmaOS
// تتيح للصيدلية تخصيص بيئة العمل (جهاز فردي / شبكة كاشيرات / فروع متعددة)
// وتوليد ونسخ رموز الاقتران والتفعيل لكل نقطة بيع وفرع

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/device_branch_manager_service.dart';

class DevicesBranchesManagementScreen extends StatefulWidget {
  const DevicesBranchesManagementScreen({super.key});

  @override
  State<DevicesBranchesManagementScreen> createState() => _DevicesBranchesManagementScreenState();
}

class _DevicesBranchesManagementScreenState extends State<DevicesBranchesManagementScreen> {
  TopologyMode _currentMode = TopologyMode.singleDevice;
  List<BranchConfig> _branches = [];
  List<DeviceConfig> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final mode = await DeviceBranchManagerService.getTopologyMode();
    final branches = await DeviceBranchManagerService.getBranches();
    final devices = await DeviceBranchManagerService.getDevices();
    if (mounted) {
      setState(() {
        _currentMode = mode;
        _branches = branches;
        _devices = devices;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMode(TopologyMode mode) async {
    await DeviceBranchManagerService.setTopologyMode(mode);
    setState(() => _currentMode = mode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث نمط تشغيل الصيدلية بنجاح'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label إلى الحافظة بنجاح'),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAddBranchDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController(text: 'BR-0${_branches.length + 1}');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('إضافة فرع جديد للصيدلية'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'اسم الفرع',
                hintText: 'مثال: فرع المستشفى، فرع السوق المركزي',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'كود الفرع',
                hintText: 'مثال: BR-02',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة الفرع وتوليد الرمز'),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await DeviceBranchManagerService.addBranch(
                name: nameController.text.trim(),
                code: codeController.text.trim(),
              );
              await _loadData();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDeviceDialog() async {
    final nameController = TextEditingController(text: 'كاشير نقطة بيع ${_devices.length + 1}');
    String selectedBranchId = _branches.isNotEmpty ? _branches.first.id : 'main';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: Colors.teal),
              SizedBox(width: 8),
              Text('إضافة جهاز كاشير / نقطة بيع'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الجهاز أو الكاشير',
                  hintText: 'مثال: كاشير الصالة 1، كاشير الطوارئ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedBranchId,
                decoration: InputDecoration(
                  labelText: 'الفرع التابع له',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _branches
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text('${b.name} (${b.code})'),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedBranchId = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('توليد رمز الاقتران'),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await DeviceBranchManagerService.addDevice(
                  branchId: selectedBranchId,
                  name: nameController.text.trim(),
                  isMainServer: false,
                );
                await _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إدارة بنية الأجهزة والفروع ونقاط البيع'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بطاقة الترحيب والتعريف
                  _buildHeaderCard(),
                  const SizedBox(height: 20),

                  // اختيار نمط بنية النظام
                  _buildTopologySelector(),
                  const SizedBox(height: 24),

                  // قسم الفروع (يظهر إذا كان النمط متعدد الفروع)
                  if (_currentMode == TopologyMode.multiBranch) ...[
                    _buildBranchesSection(),
                    const SizedBox(height: 24),
                  ],

                  // قسم الأجهزة ونقاط البيع
                  _buildDevicesSection(),
                  const SizedBox(height: 24),

                  // بطاقة الإرشادات والربط
                  _buildSecurityInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.tealAccent, size: 32),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بنية التشغيل والربط الشبكي الذكي',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'يدعم نظام PharmaOS العمل المستقل على حاسوب واحد، أو الربط الشبكي لكاشيرات متعددة، أو الإدارة المركزية متعددة الفروع مع عزل تام وتشفير فائق.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopologySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Colors.teal, size: 20),
              SizedBox(width: 8),
              Text(
                'نمط تشغيل المنظومة الحالية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTopologyOption(
            mode: TopologyMode.singleDevice,
            title: 'جهاز فردي مستقل (Single Workstation)',
            desc: 'يعمل النظام بالكامل على هذا الحاسوب (قاعدة البيانات ونقطة البيع والإدارة).',
            icon: Icons.computer_rounded,
          ),
          const SizedBox(height: 8),
          _buildTopologyOption(
            mode: TopologyMode.multiDeviceNetwork,
            title: 'شبكة كاشيرات محلية (Multi-Cashier Local Network)',
            desc: 'يرتبط هذا الحاسوب كخادم رئيسي (Server) وترتبط به أجهزة كاشير إضافية عبر الشبكة الداخلية.',
            icon: Icons.lan_rounded,
          ),
          const SizedBox(height: 8),
          _buildTopologyOption(
            mode: TopologyMode.multiBranch,
            title: 'إدارة مركزية متعددة الفروع (Multi-Branch Distributed)',
            desc: 'سلسلة صيدليات مع فرع رئيسي وفروع فرعية متصلة ومزامنة مركزية.',
            icon: Icons.account_tree_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTopologyOption({
    required TopologyMode mode,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _currentMode == mode;
    return InkWell(
      onTap: () => _updateMode(mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.withOpacity(0.06) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.teal : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.teal : Colors.grey, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? Colors.teal.shade900 : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
            ),
            Radio<TopologyMode>(
              value: mode,
              groupValue: _currentMode,
              activeColor: Colors.teal,
              onChanged: (val) {
                if (val != null) _updateMode(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.storefront_rounded, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'قائمة فروع الصيدلية المعتمدة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('إضافة فرع'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _showAddBranchDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final branch = _branches[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.withOpacity(0.1),
                      child: Text(
                        branch.code,
                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'رمز الربط: ${branch.token}',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.teal, size: 18),
                      tooltip: 'نسخ رمز الربط',
                      onPressed: () => _copyToClipboard(branch.token, 'رمز فرع ${branch.name}'),
                    ),
                    if (branch.id != 'main')
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        tooltip: 'حذف الفرع',
                        onPressed: () async {
                          await DeviceBranchManagerService.removeBranch(branch.id);
                          await _loadData();
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.devices_rounded, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'أجهزة ونقاط البيع المعتمدة (Cashiers & Terminals)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('إضافة نقطة بيع'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _showAddDeviceDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final device = _devices[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: device.isMainServer ? Colors.teal.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        device.isMainServer ? Icons.dns_rounded : Icons.point_of_sale_rounded,
                        color: device.isMainServer ? Colors.teal : Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                device.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (device.isMainServer) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.teal,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'الخادم الرئيسي',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'رمز الاقتران: ${device.token}',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.teal, size: 18),
                      tooltip: 'نسخ رمز اقتران الجهاز',
                      onPressed: () => _copyToClipboard(device.token, 'رمز اقتران ${device.name}'),
                    ),
                    if (!device.isMainServer)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        tooltip: 'حذف الجهاز',
                        onPressed: () async {
                          await DeviceBranchManagerService.removeDevice(device.id);
                          await _loadData();
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security_rounded, color: Colors.teal, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'كل رمز اقتران (Pairing Token) فريد ومحمي ومولد بخوارزمية تشفير خاصة. عند تشغيل PharmaOS على حاسوب الكاشير، يكفي إدخال رمز الاقتران ليتم الربط والمزامنة الفورية تلقائياً دون الحاجة لإعدادات شبكة معقدة.',
              style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
