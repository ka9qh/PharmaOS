// شاشة التحكم وتخصيص تفاصيل القسم بدون برمجة (No-Code Section Studio) - PharmaOS
// تتيح للصيدلي التحكم الكامل في كل ما بداخل القسم: أشرطة البحث، الأزرار المخصصة،
// الإجراءات السريعة، البطاقات الإحصائية، وعناوين العرض.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/section_customization_service.dart';

class SectionInspectorScreen extends StatefulWidget {
  final String sectionKey;
  final String sectionTitle;
  final String sectionDescription;
  final IconData sectionIcon;
  final Color sectionColor;

  const SectionInspectorScreen({
    super.key,
    required this.sectionKey,
    required this.sectionTitle,
    required this.sectionDescription,
    required this.sectionIcon,
    required this.sectionColor,
  });

  @override
  State<SectionInspectorScreen> createState() => _SectionInspectorScreenState();
}

class _SectionInspectorScreenState extends State<SectionInspectorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late SectionCustomizationConfig _config;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _availableDestinations = [
    {'title': 'شاشة نقطة البيع (POS)', 'target': '/pos', 'icon': Icons.point_of_sale},
    {'title': 'دليل الأدوية الشامل', 'target': '/medicines', 'icon': Icons.medication},
    {'title': 'مخزون الصيدلية الفعلي', 'target': '/inventory', 'icon': Icons.inventory_2},
    {'title': 'الفواتير الشاملة', 'target': '/invoices', 'icon': Icons.receipt_long},
    {'title': 'سجل العملاء والديون', 'target': '/customers', 'icon': Icons.people},
    {'title': 'كشف ديون الصيدلية (المحاسب الذكي)', 'target': '/pharmacy_debts', 'icon': Icons.account_balance_wallet},
    {'title': 'الموردون المتعامل معهم', 'target': '/active_suppliers', 'icon': Icons.handshake},
    {'title': 'الشركات المتعامل معها', 'target': '/active_companies', 'icon': Icons.business_center},
    {'title': 'فواتير الموردين غير المسددة', 'target': '/vendor_payments', 'icon': Icons.receipt},
    {'title': 'استيراد الأدوية من Excel', 'target': '/excel_import', 'icon': Icons.upload_file},
    {'title': 'إغلاق اليومية والنوبات', 'target': '/daily_closing', 'icon': Icons.lock_clock},
    {'title': 'التقارير والأرباح', 'target': '/reports', 'icon': Icons.analytics},
    {'title': 'المساعد الصيدلاني الذكي (AI)', 'target': '/ai', 'icon': Icons.auto_awesome},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.sectionTitle);
    _subtitleController = TextEditingController(text: widget.sectionDescription);
    _loadConfig();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await SectionCustomizationService.getConfig(
      widget.sectionKey,
      defaultTitle: widget.sectionTitle,
      defaultSubtitle: widget.sectionDescription,
    );
    if (mounted) {
      setState(() {
        _config = config;
        _titleController.text = config.customTitle.isNotEmpty ? config.customTitle : widget.sectionTitle;
        _subtitleController.text = config.customSubtitle.isNotEmpty ? config.customSubtitle : widget.sectionDescription;
        _isLoading = false;
      });
    }
  }

  void _showAddCustomButtonDialog() {
    final labelCtrl = TextEditingController();
    int selectedIconCode = Icons.touch_app.codePoint;
    Color selectedColor = Colors.teal;
    String selectedActionType = 'navigate_screen';
    String selectedTarget = _availableDestinations.first['target'];

    final iconsList = [
      Icons.touch_app,
      Icons.search,
      Icons.add,
      Icons.print,
      Icons.download,
      Icons.upload,
      Icons.receipt_long,
      Icons.payment,
      Icons.send,
      Icons.share,
      Icons.star,
      Icons.notifications_active,
      Icons.auto_awesome,
      Icons.chat,
    ];

    final colorsList = [
      Colors.teal,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.green,
      Colors.blueGrey,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.smart_button, color: Colors.teal),
                SizedBox(width: 8),
                Text('إضافة زر / إجراء مخصص للقسم'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'اسم الزر الظاهر للصيدلي *',
                        hintText: 'مثال: فتح التوريد السريع، كشف حساب فوري...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('وظيفة ومهمة الزر:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      value: selectedActionType,
                      items: const [
                        DropdownMenuItem(value: 'navigate_screen', child: Text('الانتقال وفتح قسم أو شاشة أخرى')),
                        DropdownMenuItem(value: 'show_alert', child: Text('إظهار تنبيه أو ملاحظة صيدلانية')),
                        DropdownMenuItem(value: 'open_url', child: Text('فتح رابط خارجي / واتساب المورد')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedActionType = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    if (selectedActionType == 'navigate_screen') ...[
                      const Text('الشاشة أو القسم المستهدف:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        value: selectedTarget,
                        items: _availableDestinations.map((d) {
                          return DropdownMenuItem<String>(
                            value: d['target'],
                            child: Row(
                              children: [
                                Icon(d['icon'] as IconData, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Text(d['title'] as String),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedTarget = val);
                        },
                      ),
                    ] else if (selectedActionType == 'show_alert') ...[
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'نص التنبيه أو الملاحظة',
                          hintText: 'مثال: تأكد من مراجعة تواريخ الصلاحية قبل البيع',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => selectedTarget = val,
                      ),
                    ] else ...[
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'الرابط أو رقم الواتساب',
                          hintText: 'https://... أو رابط خدمة',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => selectedTarget = val,
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text('اختر أيقونة الزر:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: iconsList.map((ic) {
                        final isSelected = selectedIconCode == ic.codePoint;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedIconCode = ic.codePoint),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.teal.shade100 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? Colors.teal : Colors.transparent, width: 2),
                            ),
                            child: Icon(ic, color: isSelected ? Colors.teal.shade900 : Colors.blueGrey),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text('لون الزر:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: colorsList.map((col) {
                        final isSelected = selectedColor.value == col.value;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedColor = col),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 2.5),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('إضافة الزر'),
                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () {
                  final label = labelCtrl.text.trim();
                  if (label.isEmpty) return;

                  final newBtn = CustomActionButton(
                    id: 'BTN-${DateTime.now().millisecondsSinceEpoch}',
                    label: label,
                    iconCodePoint: selectedIconCode,
                    actionType: selectedActionType,
                    target: selectedTarget,
                    colorValue: selectedColor.value,
                  );

                  setState(() {
                    _config = _config.copyWith(
                      customButtons: [..._config.customButtons, newBtn],
                    );
                  });

                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = _config.copyWith(
      customTitle: _titleController.text.trim(),
      customSubtitle: _subtitleController.text.trim(),
    );
    await SectionCustomizationService.saveConfig(updated);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ تخصيص قسم "${updated.customTitle}" وتطبيق التعديلات بنجاح ✓'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Row(
            children: [
              Icon(widget.sectionIcon, color: widget.sectionColor),
              const SizedBox(width: 8),
              Text('التحكم في قسم: ${widget.sectionTitle}'),
            ],
          ),
          actions: [
            FilledButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('حفظ التخصيص'),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: _isSaving ? null : _save,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة الرأس والأسماء
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_note, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('تسمية وعنوان القسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'اسم القسم الظاهر في النظام',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _subtitleController,
                        decoration: const InputDecoration(
                          labelText: 'الوصف التوضيحي للقسم',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // بطاقة الميزات الداخلية (أشرطة البحث، الإحصائيات، الفلاتر)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.toggle_on_outlined, color: Colors.purple),
                          SizedBox(width: 8),
                          Text('التحكم في مكونات وميزات القسم الداخلية (بدون برمجة)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('تفعيل شريط البحث الفوري في هذا القسم'),
                        subtitle: const Text('يتيح البحث السريع بالاسم، الرقم، والرمز'),
                        value: _config.showSearchBar,
                        onChanged: (val) => setState(() => _config = _config.copyWith(showSearchBar: val)),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('إظهار البطاقات الإحصائية والملخص المالي'),
                        subtitle: const Text('عرض الإجماليات، الأعداد، والمؤشرات في أعلى الشاشة'),
                        value: _config.showSummaryCards,
                        onChanged: (val) => setState(() => _config = _config.copyWith(showSummaryCards: val)),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('تفعيل فلتر واختيار التواريخ المخصص'),
                        subtitle: const Text('تصفية حسب اليوم، الأسبوع، الشهر، أو فترة محددة'),
                        value: _config.showDateFilter,
                        onChanged: (val) => setState(() => _config = _config.copyWith(showDateFilter: val)),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('إظهار زر التصدير والطباعة (PDF / Excel)'),
                        subtitle: const Text('تمكين استخراج التقارير والبيانات فورياً'),
                        value: _config.showExportButton,
                        onChanged: (val) => setState(() => _config = _config.copyWith(showExportButton: val)),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('إظهار زر الإضافة السريعة في الشريط العلوي'),
                        subtitle: const Text('زر مخصص لإدخال عنصر جديد مباشرة'),
                        value: _config.showQuickAddButton,
                        onChanged: (val) => setState(() => _config = _config.copyWith(showQuickAddButton: val)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // بطاقة الأزرار والإجراءات المخصصة
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.smart_button, color: Colors.teal),
                              SizedBox(width: 8),
                              Text('الأزرار والإجراءات المخصصة التي يحددها الصيدلي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة زر مخصص'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                            onPressed: _showAddCustomButtonDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'يمكنك إضافة أزرار سريعة داخل هذا القسم للقيام بأي مهمة أو الانتقال لأي شاشة أو إظهار تنبيه بدون كتابة كود.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      if (_config.customButtons.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Center(
                            child: Text(
                              'لا توجد أزرار مخصصة مضافة لهذا القسم حالياً.\nاضغط على "إضافة زر مخصص" لإنشاء زر جديد بالمهمة التي تريدها.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.blueGrey),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _config.customButtons.length,
                          itemBuilder: (context, index) {
                            final btn = _config.customButtons[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: btn.color.withOpacity(0.15),
                                  child: Icon(btn.icon, color: btn.color),
                                ),
                                title: Text(btn.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('نوع الإجراء: ${btn.actionType} | الهدف: ${btn.target}', style: const TextStyle(fontSize: 12)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'حذف الزر',
                                  onPressed: () {
                                    setState(() {
                                      final updated = List<CustomActionButton>.from(_config.customButtons)..removeAt(index);
                                      _config = _config.copyWith(customButtons: updated);
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
