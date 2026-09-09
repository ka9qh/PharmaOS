import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/di/service_locator.dart';
import '../../../medicines/presentation/providers/medicines_provider.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../providers/inventory_provider.dart';

class ReceiveStockDialog extends ConsumerStatefulWidget {
  final int? initialMedicineId;

  const ReceiveStockDialog({super.key, this.initialMedicineId});

  @override
  ConsumerState<ReceiveStockDialog> createState() => _ReceiveStockDialogState();
}

class _ReceiveStockDialogState extends ConsumerState<ReceiveStockDialog> {
  MedicineEntity? _selectedMedicine;
  final _searchController = TextEditingController();

  // نوع الدواء: 1: حبوب، 2: إبر، 3: زجاجي/سوائل، 0: أخرى
  int _medicineType = 1;

  // وحدات التعبئة والكميات
  final _cartonsController = TextEditingController(text: '0');
  final _packsPerCartonController = TextEditingController(text: '48');
  final _directPacksController = TextEditingController(text: '0');
  final _stripsPerPackController = TextEditingController(text: '2');
  final _pillsPerStripController = TextEditingController(text: '10');

  // الأسعار
  final _packPurchasePriceController = TextEditingController();
  final _packSellingPriceController = TextEditingController();
  final _stripPurchasePriceController = TextEditingController();
  final _stripSellingPriceController = TextEditingController();
  final _unitPurchasePriceController = TextEditingController();
  final _unitSellingPriceController = TextEditingController();

  // بيانات الدفعة
  final _batchNumberController = TextEditingController();
  DateTime? _expiryDate;

  // الحسابات المحسوبة
  int _calculatedTotalPacks = 0;
  int _calculatedTotalStrips = 0;
  int _calculatedTotalPills = 0;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialMedicineId != null) {
      _loadInitialMedicine(widget.initialMedicineId!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cartonsController.dispose();
    _packsPerCartonController.dispose();
    _directPacksController.dispose();
    _stripsPerPackController.dispose();
    _pillsPerStripController.dispose();
    _packPurchasePriceController.dispose();
    _packSellingPriceController.dispose();
    _stripPurchasePriceController.dispose();
    _stripSellingPriceController.dispose();
    _unitPurchasePriceController.dispose();
    _unitSellingPriceController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMedicine(int id) async {
    final list = ref.read(medicinesNotifierProvider).items;
    final med = list.where((m) => m.id == id).firstOrNull;
    if (med != null) {
      _selectMedicine(med);
    }
  }

  void _selectMedicine(MedicineEntity med) {
    setState(() {
      _selectedMedicine = med;
      _medicineType = med.medicineType != 0 ? med.medicineType : 1;

      if (med.qtyPerPack != null && med.qtyPerPack! > 0) {
        _stripsPerPackController.text = med.qtyPerPack.toString();
      }
      if (med.qtyPerStrip != null && med.qtyPerStrip! > 0) {
        _pillsPerStripController.text = med.qtyPerStrip.toString();
      }

      final packSell = med.packSellingPrice ?? (med.sellingPrice > 0 ? med.sellingPrice : 100.0);
      final packPurch = med.packPurchasePrice ?? (med.purchasePrice > 0 ? med.purchasePrice : (packSell * 0.8));

      _packSellingPriceController.text = packSell.toStringAsFixed(0);
      _packPurchasePriceController.text = packPurch.toStringAsFixed(0);
      
      if (med.stripSellingPrice != null && med.stripSellingPrice! > 0) {
        _stripSellingPriceController.text = med.stripSellingPrice!.toStringAsFixed(1);
        _stripPurchasePriceController.text = (med.stripPurchasePrice ?? (med.stripSellingPrice! * 0.8)).toStringAsFixed(1);
        
        _unitSellingPriceController.text = med.sellingPrice.toStringAsFixed(1);
        _unitPurchasePriceController.text = med.purchasePrice.toStringAsFixed(1);
      } else {
        _recalculatePricesFromPack();
      }
      
      _recalculateQuantities();
    });
  }

  void _recalculateQuantities() {
    final cartons = int.tryParse(_cartonsController.text) ?? 0;
    final packsPerCarton = int.tryParse(_packsPerCartonController.text) ?? 1;
    final directPacks = int.tryParse(_directPacksController.text) ?? 0;

    final totalPacks = (cartons * packsPerCarton) + directPacks;

    final stripsPerPack = int.tryParse(_stripsPerPackController.text) ?? 1;
    final pillsPerStrip = int.tryParse(_pillsPerStripController.text) ?? 1;

    final totalStrips = totalPacks * stripsPerPack;
    final totalPills = totalStrips * pillsPerStrip;

    setState(() {
      _calculatedTotalPacks = totalPacks;
      _calculatedTotalStrips = totalStrips;
      _calculatedTotalPills = totalPills;
    });
  }

  void _recalculatePricesFromPack() {
    final packSell = double.tryParse(_packSellingPriceController.text) ?? 0;
    final packPurch = double.tryParse(_packPurchasePriceController.text) ?? (packSell * 0.8);

    final stripsPerPack = int.tryParse(_stripsPerPackController.text) ?? 1;
    final pillsPerStrip = int.tryParse(_pillsPerStripController.text) ?? 1;

    final stripSell = stripsPerPack > 0 ? (packSell / stripsPerPack) : packSell;
    final stripPurch = stripsPerPack > 0 ? (packPurch / stripsPerPack) : packPurch;

    final pillSell = pillsPerStrip > 0 ? (stripSell / pillsPerStrip) : stripSell;
    final pillPurch = pillsPerStrip > 0 ? (stripPurch / pillsPerStrip) : stripPurch;

    _stripSellingPriceController.text = stripSell.toStringAsFixed(1);
    _stripPurchasePriceController.text = stripPurch.toStringAsFixed(1);
    _unitSellingPriceController.text = pillSell.toStringAsFixed(1);
    _unitPurchasePriceController.text = pillPurch.toStringAsFixed(1);
  }

  Future<void> _saveStock() async {
    if (_selectedMedicine == null) {
      setState(() => _errorMessage = 'يرجى اختيار الدواء أولاً');
      return;
    }

    if (_calculatedTotalPills <= 0 && _calculatedTotalPacks <= 0) {
      setState(() => _errorMessage = 'يرجى إدخال كمية صحيحة (كراتين أو بواكت)');
      return;
    }

    if (_expiryDate == null) {
      setState(() => _errorMessage = 'يرجى إدخال تاريخ الصلاحية');
      return;
    }

    final unitPurchPrice = double.tryParse(_unitPurchasePriceController.text) ??
        (double.tryParse(_packPurchasePriceController.text) ?? 0);

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final totalBaseQuantity = _calculatedTotalPills > 0 ? _calculatedTotalPills : _calculatedTotalPacks;

      final ok = await ref.read(inventoryNotifierProvider.notifier).receiveStock(
            medicineId: _selectedMedicine!.id,
            batchNumber: _batchNumberController.text.trim().isEmpty ? null : _batchNumberController.text.trim(),
            expiryDate: _expiryDate,
            quantity: totalBaseQuantity,
            purchasePrice: unitPurchPrice,
          );

      // تحديث أسعار وتعبئة الدواء
      final qtyPerPack = int.tryParse(_stripsPerPackController.text);
      final qtyPerStrip = int.tryParse(_pillsPerStripController.text);
      final packSell = double.tryParse(_packSellingPriceController.text);
      final packPurch = double.tryParse(_packPurchasePriceController.text);
      final stripSell = double.tryParse(_stripSellingPriceController.text);
      final stripPurch = double.tryParse(_stripPurchasePriceController.text);

      final updatedMed = _selectedMedicine!.copyWith(
        purchasePrice: unitPurchPrice,
        sellingPrice: double.tryParse(_unitSellingPriceController.text) ?? _selectedMedicine!.sellingPrice,
        qtyPerPack: qtyPerPack,
        qtyPerStrip: qtyPerStrip,
        packPurchasePrice: packPurch,
        packSellingPrice: packSell,
        stripPurchasePrice: stripPurch,
        stripSellingPrice: stripSell,
        medicineType: _medicineType,
      );
      await ref.read(medicinesNotifierProvider.notifier).updateMedicine(updatedMed);

      if (ok && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إضافة ${_selectedMedicine!.nameAr} إلى مخزون الصيدلية بنجاح ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'حدث خطأ أثناء الحفظ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMedicines = ref.watch(medicinesNotifierProvider).items;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: 750,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_business, color: Colors.green, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إضافة دواء إلى مخزون الصيدلية',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'حدد الدواء والكميات والتعبئة (كرتون -> باكت -> شريط -> حبة)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: ListView(
                  children: [
                    // 1. اختيار الدواء
                    if (_selectedMedicine == null) ...[
                      const Text('1. ابحث عن الدواء في دليل أدوية السوق:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'اكتب اسم الدواء بالعربي أو الإنجليزي أو الباركود...',
                          prefixIcon: const Icon(Icons.search, color: Colors.blue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (val) {
                          ref.read(medicinesNotifierProvider.notifier).search(val);
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.separated(
                          itemCount: allMedicines.take(30).length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final med = allMedicines[index];
                            return ListTile(
                              dense: true,
                              title: Text(med.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${med.nameEn ?? ""} | ${med.nameScientific ?? ""} | الباركود: ${med.barcode}'),
                              trailing: FilledButton.tonal(
                                onPressed: () => _selectMedicine(med),
                                child: const Text('اختيار'),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      // بطاقة الدواء المختار
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.medication, color: Colors.blue, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedMedicine!.nameAr,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${_selectedMedicine!.nameEn ?? ""} | علمي: ${_selectedMedicine!.nameScientific ?? ""} | باركود: ${_selectedMedicine!.barcode}',
                                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.change_circle_outlined),
                              label: const Text('تغيير'),
                              onPressed: () => setState(() => _selectedMedicine = null),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 2. نوع الدواء
                    const Text('2. تصنيف وشكل الدواء:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('حبوب وأقراص'), icon: Icon(Icons.circle_outlined)),
                        ButtonSegment(value: 2, label: Text('إبر وحقن'), icon: Icon(Icons.colorize_outlined)),
                        ButtonSegment(value: 3, label: Text('زجاجي وسوائل'), icon: Icon(Icons.water_drop_outlined)),
                        ButtonSegment(value: 0, label: Text('مراهم وأخرى'), icon: Icon(Icons.medical_services_outlined)),
                      ],
                      selected: {_medicineType},
                      onSelectionChanged: (newSet) {
                        setState(() {
                          _medicineType = newSet.first;
                          if (_medicineType != 1) {
                            _stripsPerPackController.text = '1';
                            _pillsPerStripController.text = '1';
                          }
                          _recalculateQuantities();
                          _recalculatePricesFromPack();
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // 3. إدخال الكميات والحساب الهرمي
                    const Text('3. الكميات المستلمة (الحساب الهرمي التلقائي):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cartonsController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'عدد الكراتين',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.inventory_2),
                                  ),
                                  onChanged: (_) => _recalculateQuantities(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _packsPerCartonController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'كم باكت داخل الكرتون؟',
                                    border: OutlineInputBorder(),
                                    helperText: 'مثال: 48 باكت',
                                  ),
                                  onChanged: (_) => _recalculateQuantities(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _directPacksController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'بواكت إضافية فردية',
                                    border: OutlineInputBorder(),
                                    helperText: 'إن وُجد',
                                  ),
                                  onChanged: (_) => _recalculateQuantities(),
                                ),
                              ),
                            ],
                          ),
                          if (_medicineType == 1) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _stripsPerPackController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'كم شريط داخل الباكت؟',
                                      border: OutlineInputBorder(),
                                      helperText: 'مثال: 2 أو 3 شريط',
                                    ),
                                    onChanged: (_) {
                                      _recalculateQuantities();
                                      _recalculatePricesFromPack();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _pillsPerStripController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'كم حبة داخل الشريط؟',
                                      border: OutlineInputBorder(),
                                      helperText: 'مثال: 10 أو 12 حبة',
                                    ),
                                    onChanged: (_) {
                                      _recalculateQuantities();
                                      _recalculatePricesFromPack();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          // بطاقة ملخص الحساب التلقائي
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text(
                                  'إجمالي البواكت: $_calculatedTotalPacks باكت',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                if (_medicineType == 1) ...[
                                  Text(
                                    'إجمالي الأشرطة: $_calculatedTotalStrips شريط',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                  Text(
                                    'إجمالي الحبات: $_calculatedTotalPills حبة',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4. أسعار الشراء والبيع
                    const Text('4. أسعار الشراء والبيع لكل مستوى:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _packPurchasePriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سعر شراء الباكت',
                              border: OutlineInputBorder(),
                              suffixText: 'ر.ي',
                            ),
                            onChanged: (_) => _recalculatePricesFromPack(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _packSellingPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سعر بيع الباكت',
                              border: OutlineInputBorder(),
                              suffixText: 'ر.ي',
                            ),
                            onChanged: (_) => _recalculatePricesFromPack(),
                          ),
                        ),
                      ],
                    ),
                    if (_medicineType == 1) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _stripPurchasePriceController,
                              keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'سعر شراء الشريط',
                                  border: OutlineInputBorder(),
                                  suffixText: 'ر.ي',
                                ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _stripSellingPriceController,
                              keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'سعر بيع الشريط',
                                  border: OutlineInputBorder(),
                                  suffixText: 'ر.ي',
                                ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _unitSellingPriceController,
                              keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'سعر بيع الحبة',
                                  border: OutlineInputBorder(),
                                  suffixText: 'ر.ي',
                                ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 5. الصلاحية ورقم التشغيلة
                    const Text('5. رقم التشغيلة وتاريخ الصلاحية:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _batchNumberController,
                            decoration: const InputDecoration(
                              labelText: 'رقم التشغيلة (Batch No - اختياري)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 365)),
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                              );
                              if (picked != null) {
                                setState(() => _expiryDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'تاريخ الصلاحية (إلزامي)',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.calendar_today),
                                errorText: _errorMessage != null && _expiryDate == null ? 'يرجى إدخال تاريخ الصلاحية' : null,
                              ),
                              child: Text(
                                _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : 'انقر لتحديد التاريخ',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // أزرار الحفظ والإلغاء
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: const Text('إضافة إلى المخزون'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onPressed: _isSaving ? null : _saveStock,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
