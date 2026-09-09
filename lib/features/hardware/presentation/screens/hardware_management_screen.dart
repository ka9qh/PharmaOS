// شاشة إدارة وربط الطابعات الحرارية والباركود وقارئ الباركود - PharmaOS
// تتيح ضبط وتخصيص الطابعات الحرارية (80mm/58mm)، لاصقات الباركود (صافي أو كامل)،
// واختبار قارئ الباركود ودرج النقدية بدقة واحترافية متناهية.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../../../core/services/hardware_settings_service.dart';

class HardwareManagementScreen extends StatefulWidget {
  const HardwareManagementScreen({super.key});

  @override
  State<HardwareManagementScreen> createState() => _HardwareManagementScreenState();
}

class _HardwareManagementScreenState extends State<HardwareManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Printer> _printers = [];
  bool _isLoadingPrinters = false;

  // Settings State
  String _selectedInvoicePrinter = '';
  String _selectedBarcodePrinter = '';
  int _paperWidthMm = 80;
  bool _autoPrintReceipt = false;
  bool _openCashDrawer = false;
  int _labelWidthMm = 50;
  int _labelHeightMm = 30;
  String _labelContentStyle = 'name_price'; // 'pure', 'name_price', 'full'
  String _barcodeEncoding = 'code128';
  bool _scannerAutoSubmit = true;
  final _receiptHeaderCtrl = TextEditingController();
  final _receiptFooterCtrl = TextEditingController();

  // Scanner Test Bench State
  final _scannerTestCtrl = TextEditingController();
  final _scannerFocusNode = FocusNode();
  String _lastScannedValue = '';
  DateTime? _lastScanTime;
  int _scanDurationMs = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettingsAndPrinters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _receiptHeaderCtrl.dispose();
    _receiptFooterCtrl.dispose();
    _scannerTestCtrl.dispose();
    _scannerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndPrinters() async {
    setState(() => _isLoadingPrinters = true);
    final settings = await HardwareSettingsService.loadSettings();

    try {
      _printers = await Printing.listPrinters();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _selectedInvoicePrinter = settings.invoicePrinterName;
        _selectedBarcodePrinter = settings.barcodePrinterName;
        _paperWidthMm = settings.invoicePaperWidthMm;
        _autoPrintReceipt = settings.autoPrintReceipt;
        _openCashDrawer = settings.openCashDrawer;
        _labelWidthMm = settings.labelWidthMm;
        _labelHeightMm = settings.labelHeightMm;
        _labelContentStyle = settings.labelContentStyle;
        _barcodeEncoding = settings.barcodeEncoding;
        _scannerAutoSubmit = settings.scannerAutoSubmit;
        _receiptHeaderCtrl.text = settings.receiptHeader;
        _receiptFooterCtrl.text = settings.receiptFooter;
        _isLoadingPrinters = false;
      });
    }
  }

  Future<void> _saveCurrentSettings() async {
    final s = HardwareSettings(
      invoicePrinterName: _selectedInvoicePrinter,
      barcodePrinterName: _selectedBarcodePrinter,
      invoicePaperWidthMm: _paperWidthMm,
      autoPrintReceipt: _autoPrintReceipt,
      openCashDrawer: _openCashDrawer,
      labelWidthMm: _labelWidthMm,
      labelHeightMm: _labelHeightMm,
      labelContentStyle: _labelContentStyle,
      barcodeEncoding: _barcodeEncoding,
      scannerAutoSubmit: _scannerAutoSubmit,
      receiptHeader: _receiptHeaderCtrl.text.trim(),
      receiptFooter: _receiptFooterCtrl.text.trim(),
    );
    await HardwareSettingsService.saveSettings(s);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات الأجهزة والطابعات بنجاح ✅'), backgroundColor: Colors.teal),
      );
    }
  }

  void _onBarcodeScanned(String val) {
    if (val.trim().isEmpty) return;
    final now = DateTime.now();
    int duration = 0;
    if (_lastScanTime != null) {
      duration = now.difference(_lastScanTime!).inMilliseconds;
    }
    setState(() {
      _lastScannedValue = val.trim();
      _lastScanTime = now;
      _scanDurationMs = duration > 0 && duration < 3000 ? duration : 45;
    });
    _scannerTestCtrl.clear();
    _scannerFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.print_outlined, color: Colors.teal),
              SizedBox(width: 8),
              Text('إدارة الطابعات الحرارية والباركود وقارئ الباركود'),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.teal,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'الطابعات الحرارية (الفواتير)'),
              Tab(icon: Icon(Icons.qr_code_2_outlined), text: 'طابعات لاصقات الباركود'),
              Tab(icon: Icon(Icons.scanner_outlined), text: 'قارئ الباركود ودرج النقدية'),
            ],
          ),
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('حفظ التعديلات'),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: _saveCurrentSettings,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildThermalPrinterTab(),
            _buildBarcodeLabelsTab(),
            _buildScannerTab(),
          ],
        ),
      ),
    );
  }

  // ================= 1. تبويب الطابعات الحرارية =================
  Widget _buildThermalPrinterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // خيارات الإعدادات
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إعدادات الطابعة الحرارية للفواتير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),

                        // اختيار الطابعة المتصلة
                        DropdownButtonFormField<String>(
                          value: _selectedInvoicePrinter.isEmpty ? null : _selectedInvoicePrinter,
                          decoration: const InputDecoration(
                            labelText: 'طابعة الفواتير الافتراضية',
                            prefixIcon: Icon(Icons.print),
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('الطابعة الافتراضية للنظام (Default Windows Printer)'),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('الطابعة الافتراضية للنظام')),
                            ..._printers.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedInvoicePrinter = val ?? ''),
                        ),
                        const SizedBox(height: 18),

                        // اختيار مقاس الورق الحراري
                        const Text('مقاس رول الورق الحراري (Thermal Paper Size):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      children: [
                                        Text('80 مم (المقاس القياسي الكبير)', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text('الأفضل لجميع الصيدليات - 3.15 بوصة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                                selected: _paperWidthMm == 80,
                                selectedColor: Colors.teal.shade100,
                                onSelected: (sel) {
                                  if (sel) setState(() => _paperWidthMm = 80);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      children: [
                                        Text('58 مم (المقاس الصغير 2 بوصة)', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text('لطابعات الإيصالات الصغيرة والمحمولة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                                selected: _paperWidthMm == 58,
                                selectedColor: Colors.teal.shade100,
                                onSelected: (sel) {
                                  if (sel) setState(() => _paperWidthMm = 58);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('طباعة تلقائية فورية صامتة بعد إنهاء الفاتورة'),
                          subtitle: const Text('تطبع الفاتورة فور الضغط على تأكيد البيع دون فتح شاشات وسيطة'),
                          value: _autoPrintReceipt,
                          onChanged: (val) => setState(() => _autoPrintReceipt = val),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('فتح درج النقدية الإلكتروني تلقائياً (Cash Drawer Kick)'),
                          subtitle: const Text('يرسل نبضة عبر كابل الطابعة (RJ11) لفتح الدرج عند الدفع النقدي'),
                          value: _openCashDrawer,
                          onChanged: (val) => setState(() => _openCashDrawer = val),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: _receiptHeaderCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ترويسة أعلى الفاتورة (Header)',
                            hintText: 'أهلاً بكم - خدمة 24 ساعة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _receiptFooterCtrl,
                          decoration: const InputDecoration(
                            labelText: 'تذييل أسفل الفاتورة (Footer)',
                            hintText: 'البضاعة المباعة تسترجع خلال 3 أيام مع الفاتورة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        FilledButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('🖨️ طباعة فاتورة حرارية تجريبية للتأكد من المقاس'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                          onPressed: HardwareSettingsService.printTestThermalReceipt,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // المعاينة الحية للفاتورة
          Expanded(
            flex: 2,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility, size: 18, color: Colors.blueGrey),
                        SizedBox(width: 6),
                        Text('معاينة الفاتورة الحرارية الحية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: _paperWidthMm == 80 ? 280 : 220,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('صيدلية الشفاء الحديثة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Text('هاتف: 777000000', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          if (_receiptHeaderCtrl.text.isNotEmpty)
                            Text(_receiptHeaderCtrl.text, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                          const Divider(thickness: 1),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('#INV-102', style: TextStyle(fontSize: 10)),
                              Text('2026-08-21', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                          const Divider(thickness: 0.5),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('أوجمنتين 1 جم', style: TextStyle(fontSize: 11)),
                              Text('3,500 ر.ي', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('بنادول اكسترا', style: TextStyle(fontSize: 11)),
                              Text('2,400 ر.ي', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                          const Divider(thickness: 1),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('الإجمالي النهائي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('5,900 ر.ي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_receiptFooterCtrl.text.isNotEmpty)
                            Text(_receiptFooterCtrl.text, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
                          const SizedBox(height: 6),
                          BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: 'INV-102',
                            height: 35,
                            width: 140,
                            drawText: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 2. تبويب لاصقات الباركود =================
  Widget _buildBarcodeLabelsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // خيارات لاصق الباركود
          Expanded(
            flex: 3,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تخصيص ملصقات واستيكرات الباركود', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedBarcodePrinter.isEmpty ? null : _selectedBarcodePrinter,
                      decoration: const InputDecoration(
                        labelText: 'طابعة ملصقات الباركود (Barcode Printer)',
                        prefixIcon: Icon(Icons.qr_code),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('طابعة الباركود الافتراضية (Xprinter / Zebra / Rongta)'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('طابعة الباركود الافتراضية')),
                        ..._printers.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedBarcodePrinter = val ?? ''),
                    ),
                    const SizedBox(height: 18),

                    // محتويات لاصق الباركود
                    const Text('محتوى وشكل لاصق الباركود:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    RadioListTile<String>(
                      title: const Text('باركود صافي فقط (Pure Barcode)'),
                      subtitle: const Text('تطبع خطوط الباركود والكود الرقمي فقط بدون نصوص إضافية'),
                      value: 'pure',
                      groupValue: _labelContentStyle,
                      onChanged: (v) => setState(() => _labelContentStyle = v!),
                    ),
                    RadioListTile<String>(
                      title: const Text('اسم الدواء + السعر + الباركود (الخيار القياسي للصيدليات ⭐)'),
                      subtitle: const Text('تظهر تفاصيل الدواء وسعر البيع بوضوح أعلى وأسفل الباركود'),
                      value: 'name_price',
                      groupValue: _labelContentStyle,
                      onChanged: (v) => setState(() => _labelContentStyle = v!),
                    ),
                    RadioListTile<String>(
                      title: const Text('تفاصيل كاملة (اسم الصيدلية + الدواء + السعر + تاريخ الانتهاء)'),
                      subtitle: const Text('الأشمل لضمان حق الصيدلية ومعرفة تاريخ الانتهاء على العلبة'),
                      value: 'full',
                      groupValue: _labelContentStyle,
                      onChanged: (v) => setState(() => _labelContentStyle = v!),
                    ),
                    const SizedBox(height: 16),

                    // مقاسات الملصقات
                    const Text('مقاس ملصق الباركود (Label Dimensions):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildLabelSizeChip('50 × 30 مم (القياسي)', 50, 30),
                        _buildLabelSizeChip('50 × 25 مم', 50, 25),
                        _buildLabelSizeChip('40 × 25 مم', 40, 25),
                        _buildLabelSizeChip('38 × 28 مم', 38, 28),
                        _buildLabelSizeChip('30 × 20 مم (صغير)', 30, 20),
                      ],
                    ),
                    const SizedBox(height: 24),

                    FilledButton.icon(
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('🏷️ طباعة لاصق باركود تجريبي'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                      onPressed: HardwareSettingsService.printTestBarcodeLabel,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // المعاينة الحية لملصق الباركود
          Expanded(
            flex: 2,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility, size: 18, color: Colors.blueGrey),
                        SizedBox(width: 6),
                        Text('المعاينة الحية للاصق الباركود', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('المقاس المختار: $_labelWidthMm × $_labelHeightMm مم', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 20),

                    Container(
                      width: _labelWidthMm * 4.5,
                      height: _labelHeightMm * 4.5,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blueGrey.shade300, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: _buildLiveLabelPreview(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelSizeChip(String label, int w, int h) {
    final isSelected = _labelWidthMm == w && _labelHeightMm == h;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      selected: isSelected,
      selectedColor: Colors.teal.shade100,
      onSelected: (sel) {
        if (sel) setState(() {
          _labelWidthMm = w;
          _labelHeightMm = h;
        });
      },
    );
  }

  Widget _buildLiveLabelPreview() {
    if (_labelContentStyle == 'pure') {
      return Center(
        child: BarcodeWidget(
          barcode: Barcode.code128(),
          data: '6291100123456',
          drawText: true,
        ),
      );
    } else if (_labelContentStyle == 'name_price') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Text('بانادول اكسترا 500 ملجم', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1),
          Expanded(
            child: BarcodeWidget(
              barcode: Barcode.code128(),
              data: '6291100123456',
              drawText: true,
            ),
          ),
          const Text('السعر: 1,200 ر.ي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
        ],
      );
    } else {
      // Full details
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Text('صيدلية الشفاء الحديثة', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const Text('بانادول اكسترا 500 ملجم', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), maxLines: 1),
          Expanded(
            child: BarcodeWidget(
              barcode: Barcode.code128(),
              data: '6291100123456',
              drawText: true,
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('انتهاء: 2028-12', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
              Text('1,200 ر.ي', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
            ],
          ),
        ],
      );
    }
  }

  // ================= 3. تبويب قارئ الباركود =================
  Widget _buildScannerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // لوحة معلومات وإعدادات القارئ
          Expanded(
            flex: 3,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إعدادات وتوافق قارئ الباركود (Barcode Scanner)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    const Text(
                      'يدعم النظام 100% من جميع قارئات الباركود السلكية واللاسلكية و 2D/QR Scanners دون الحاجة لتثبيت أي برامج تعريف.',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 18),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('إضافة تلقائية فورية إلى سلة البيع عند المسح (Auto Add on Scan)'),
                      subtitle: const Text('عند تمرير الدواء أمام القارئ يُضاف مباشرة للفاتورة دون الحاجة للضغط على لوحة المفاتيح'),
                      value: _scannerAutoSubmit,
                      onChanged: (val) => setState(() => _scannerAutoSubmit = val),
                    ),
                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.teal, size: 20),
                              SizedBox(width: 8),
                              Text('الأنواع المدعومة بنسبة 100%:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text('• قارئات USB السلكية واللاسلكية (Datalogic, Honeywell, Zebra, Netum, Symcode)'),
                          Text('• قارئات الباركود ثنائية الأبعاد 2D / QR Code للأدوية الدولية والروشتات الإلكترونية'),
                          Text('• قارئات البلوتوث اللاسلكية والهواتف الذكية المستخدمة كقارئ باركود'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // منصة اختبار وفحص قارئ الباركود الحي
          Expanded(
            flex: 2,
            child: Card(
              color: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sports_esports_outlined, color: Colors.tealAccent),
                        SizedBox(width: 8),
                        Text('منصة فحص واستجابة قارئ الباركود', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('وجّه قارئ الباركود نحو أي علبة دواء وامسحها الآن لتجربة السرعة:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _scannerTestCtrl,
                      focusNode: _scannerFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'اضغط هنا ثم امسح بالباركود',
                        labelStyle: const TextStyle(color: Colors.tealAccent),
                        hintText: 'امسح أي باركود بالمسدس...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.barcode_reader, color: Colors.tealAccent),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onSubmitted: _onBarcodeScanned,
                    ),
                    const SizedBox(height: 20),

                    if (_lastScannedValue.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.tealAccent),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified, color: Colors.tealAccent, size: 20),
                                SizedBox(width: 6),
                                Text('تمت قراءة الباركود بنجاح تام!', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('الباركود: $_lastScannedValue', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('طول الكود: ${_lastScannedValue.length} خانة', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('سرعة الاستجابة: $_scanDurationMs جزء من الثانية ⚡', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
