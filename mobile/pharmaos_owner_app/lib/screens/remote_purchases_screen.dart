// شاشة إدارة وإدخال فواتير الشراء الشاملة عن بعد - PharmaOS Owner App
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/models.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';
import '../widgets/luxury_background.dart';

class RemotePurchasesScreen extends StatefulWidget {
  const RemotePurchasesScreen({super.key});

  @override
  State<RemotePurchasesScreen> createState() => _RemotePurchasesScreenState();
}

class _RemotePurchasesScreenState extends State<RemotePurchasesScreen> {
  List<RemotePurchaseInvoice> _invoices = [];
  List<CloudSupplier> _suppliers = [];
  List<CloudMedicine> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final invs = await OwnerApiService.fetchPurchasesHistory();
    final sups = await OwnerApiService.fetchSuppliers();
    final meds = await OwnerApiService.fetchMedicinesCatalog();

    if (mounted) {
      setState(() {
        _invoices = invs;
        _suppliers = sups;
        _medicines = meds;
        _isLoading = false;
      });
    }
  }

  void _openNewPurchaseDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewPurchaseInvoiceSheet(
        suppliers: _suppliers,
        medicines: _medicines,
        onCreated: (newInv) {
          setState(() {
            _invoices.insert(0, newInv);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: OwnerTheme.primaryEmerald,
              content: Text('تم إرسال وتزامن فاتورة الشراء رقم #${newInv.invoiceNumber} لحظياً مع النظام المكتبي'),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryBackground(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C1322).withValues(alpha: 0.85),
          elevation: 0,
          title: const Text('فواتير الشراء والموردين 📦'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: OwnerTheme.primaryEmerald,
          icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
          label: const Text('إدخال فاتورة شراء جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: _openNewPurchaseDialog,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: OwnerTheme.primaryEmeraldLight))
            : _invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 64, color: Colors.white.withOpacity(0.15)),
                        const SizedBox(height: 16),
                        const Text('لا توجد فواتير شراء سابقة', style: TextStyle(color: Colors.white60, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text('اضغط على الزر بالأسفل لإدخال فاتورة شراء تتزامن فورياً مع النظام', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final inv = _invoices[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: OwnerTheme.glassCardDecoration(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: OwnerTheme.primaryEmerald.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.inventory_2_rounded, color: OwnerTheme.primaryEmeraldLight, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'فاتورة #${inv.invoiceNumber}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (inv.paymentType == 'cash' ? Colors.green : Colors.orange).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      inv.paymentType == 'cash' ? 'نقدي' : 'آجل',
                                      style: TextStyle(
                                        color: inv.paymentType == 'cash' ? Colors.greenAccent : Colors.orangeAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: OwnerTheme.surfaceBorder, height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المورد: ${inv.supplierName}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                  Text(
                                    '${inv.totalAmount.toStringAsFixed(0)} ر.ي',
                                    style: const TextStyle(color: OwnerTheme.accentGoldLight, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'عدد الأصناف: ${inv.items.length}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                  ),
                                  Text(
                                    DateFormat('yyyy-MM-dd HH:mm').format(inv.invoiceDate),
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }
}

class _NewPurchaseInvoiceSheet extends StatefulWidget {
  final List<CloudSupplier> suppliers;
  final List<CloudMedicine> medicines;
  final Function(RemotePurchaseInvoice) onCreated;

  const _NewPurchaseInvoiceSheet({
    required this.suppliers,
    required this.medicines,
    required this.onCreated,
  });

  @override
  State<_NewPurchaseInvoiceSheet> createState() => _NewPurchaseInvoiceSheetState();
}

class _NewPurchaseInvoiceSheetState extends State<_NewPurchaseInvoiceSheet> {
  final TextEditingController _invoiceNumController = TextEditingController(text: 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _paymentType = 'cash';
  final List<RemotePurchaseItem> _items = [];

  // حقول إضافة صنف للفاتورة
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _batchController = TextEditingController(text: 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
  final TextEditingController _qtyController = TextEditingController(text: '10');
  final TextEditingController _costController = TextEditingController(text: '1000');
  final TextEditingController _sellController = TextEditingController(text: '1400');
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));

  bool _isSubmitting = false;

  void _addItem() {
    final name = _itemNameController.text.trim();
    if (name.isEmpty) return;

    final qty = int.tryParse(_qtyController.text) ?? 1;
    final cost = double.tryParse(_costController.text) ?? 0.0;
    final sell = double.tryParse(_sellController.text) ?? 0.0;
    final batch = _batchController.text.trim();

    setState(() {
      _items.add(RemotePurchaseItem(
        medicineName: name,
        batchNumber: batch.isNotEmpty ? batch : 'B-01',
        expiryDate: _expiryDate,
        quantity: qty,
        purchasePrice: cost,
        sellingPrice: sell,
      ));
      _itemNameController.clear();
      _batchController.text = 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    });
  }

  double get _totalAmount => _items.fold(0.0, (sum, i) => sum + (i.purchasePrice * i.quantity));

  Future<void> _submitInvoice() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة صنف واحد على الأقل للفاتورة')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final invoice = RemotePurchaseInvoice(
      invoiceNumber: _invoiceNumController.text.trim(),
      supplierName: _supplierNameController.text.trim().isNotEmpty ? _supplierNameController.text.trim() : 'مورد عام',
      invoiceDate: DateTime.now(),
      paymentType: _paymentType,
      notes: _notesController.text.trim(),
      items: _items,
      totalAmount: _totalAmount,
      paidAmount: _paymentType == 'cash' ? _totalAmount : 0.0,
    );

    await OwnerApiService.createPurchaseInvoice(invoice);

    if (mounted) {
      setState(() => _isSubmitting = false);
      widget.onCreated(invoice);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: OwnerTheme.darkBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // شريط السحب والعنوان
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: OwnerTheme.darkCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إدخال فاتورة شراء وتوريد جديدة 📥', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بيانات الفاتورة الأساسية
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: OwnerTheme.glassCardDecoration(),
                      child: Column(
                        children: [
                          TextField(
                            controller: _invoiceNumController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'رقم فاتورة الشراء / المرجع'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _supplierNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'اسم المورد / الشركة'),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text('طريقة الدفع:', style: TextStyle(color: Colors.white70)),
                              const SizedBox(width: 14),
                              ChoiceChip(
                                label: const Text('نقدي'),
                                selected: _paymentType == 'cash',
                                onSelected: (_) => setState(() => _paymentType = 'cash'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('آجل / ذمم'),
                                selected: _paymentType == 'credit',
                                onSelected: (_) => setState(() => _paymentType = 'credit'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // إضافة صنف للفاتورة
                    const Text('إضافة أصناف للفاتورة:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: OwnerTheme.glassCardDecoration(),
                      child: Column(
                        children: [
                          TextField(
                            controller: _itemNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'اسم الدواء / الصنف'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'الكمية'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _costController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'سعر الشراء (ر.ي)'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _sellController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'سعر البيع (ر.ي)'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _batchController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'رقم التشغيلة (Batch)'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: _addItem,
                                child: const Text('+ إضافة الصنف'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // قائمة الأصناف المضافة
                    if (_items.isNotEmpty) ...[
                      const Text('الأصناف في هذه الفاتورة:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ..._items.map((i) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: OwnerTheme.darkCardElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${i.medicineName} (${i.quantity} عبوة)', style: const TextStyle(color: Colors.white)),
                                Text('${(i.purchasePrice * i.quantity).toStringAsFixed(0)} ر.ي', style: const TextStyle(color: OwnerTheme.accentGoldLight, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: OwnerTheme.primaryEmerald.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: OwnerTheme.primaryEmeraldLight),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('إجمالي الفاتورة:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('${_totalAmount.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // زر الحفظ والتزامن
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitInvoice,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('حفظ وتزامن الفاتورة لحظياً مع النظام 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
