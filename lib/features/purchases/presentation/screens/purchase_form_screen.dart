
// شاشة إنشاء فاتورة شراء جديدة - قائمة أسطر ديناميكية (كل سطر = دواء + كمية +
// تكلفة + رقم دفعة اختياري + تاريخ صلاحية اختياري). كل سطر يُنشئ Batch جديدة عند الحفظ.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/purchases_provider.dart';
import '../controllers/purchases_controller.dart';
import '../../domain/entities/purchases_entity.dart';
import '../../../../core/widgets/searchable_entity_picker.dart';
import '../../../suppliers/presentation/providers/suppliers_provider.dart';
import '../../../medicines/presentation/providers/medicines_provider.dart';

import '../../../medicines/presentation/providers/medicines_provider.dart';
import '../../../medicines/presentation/screens/medicine_form_screen.dart';
import '../../../../core/widgets/multi_unit_quantity_widget.dart';
import 'dart:io';
import 'ai_invoice_scanner_screen.dart';

class _DraftLine {
  int? medicineId;
  String medicineName = '';
  int totalPills = 0;
  int qtyCarton = 0;
  int qtyPack = 0;
  int qtyStrip = 0;
  int qtyPill = 0;
  
  int? qtyPerCarton;
  int? qtyPerPack;
  int? qtyPerStrip;
  int medicineType = 1;
  
  final costController = TextEditingController();
  final sellingPriceController = TextEditingController();
  final batchNumberController = TextEditingController();
  DateTime? expiryDate;
}

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  int? _supplierId;
  final _supplierInvoiceController = TextEditingController();
  final _paidAmountController = TextEditingController(text: '0');
  final List<_DraftLine> _lines = [_DraftLine()];
  bool _isSaving = false;
  String? _supplierError;
  String? _invoiceImagePath;

  double get _totalAmount => _lines.fold(0.0, (sum, l) {
        final cost = double.tryParse(l.costController.text) ?? 0;
        return sum + cost;
      });

  void _addLine() => setState(() => _lines.add(_DraftLine()));

  void _removeLine(int index) => setState(() => _lines.removeAt(index));

  Future<void> _scanInvoiceWithAi() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiInvoiceScannerScreen()),
    );
    if (result != null && result is Map<String, dynamic>) {
      // 1. Assign supplier if found and exists
      final String? supplierName = result['supplierName'];
      if (supplierName != null && supplierName.isNotEmpty) {
        final suppliers = ref.read(suppliersNotifierProvider).items;
        final supplier = suppliers.where((s) => s.name.contains(supplierName) || supplierName.contains(s.name)).firstOrNull;
        if (supplier != null) {
          setState(() {
            _supplierId = supplier.id;
          });
        }
      }
      
      // 2. Set invoice number and image path
      if (result['invoiceNumber'] != null) {
        _supplierInvoiceController.text = result['invoiceNumber'].toString();
      }
      if (result['savedImagePath'] != null) {
        setState(() {
          _invoiceImagePath = result['savedImagePath'];
        });
      }

      // 3. Map items
      final List<dynamic>? items = result['items'];
      if (items != null && items.isNotEmpty) {
        final medicines = ref.read(medicinesNotifierProvider).items;
        setState(() {
          _lines.clear();
          for (final item in items) {
            final line = _DraftLine();
            final String name = item['name'] ?? '';
            final med = medicines.where((m) => m.nameAr.contains(name) || (m.nameEn != null && m.nameEn!.contains(name))).firstOrNull;
            if (med != null) {
              line.medicineId = med.id;
              line.medicineName = med.nameAr;
              line.qtyPerCarton = med.qtyPerCarton;
              line.qtyPerPack = med.qtyPerPack;
              line.qtyPerStrip = med.qtyPerStrip;
            } else {
              line.medicineName = name;
            }
            
            line.qtyCarton = item['qtyCarton'] ?? 0;
            line.qtyPack = item['qtyPack'] ?? 0;
            line.qtyStrip = item['qtyStrip'] ?? 0;
            line.qtyPill = item['qtyPill'] ?? 0;
            line.totalPills = item['totalPills'] ?? 0;
            
            line.costController.text = (item['unitCost'] ?? 0).toString();
            _lines.add(line);
          }
          if (_lines.isEmpty) _lines.add(_DraftLine());
        });
      }
    }
  }

  Future<void> _save() async {
    final supplierError = PurchasesController.validateSupplier(_supplierId);
    setState(() => _supplierError = supplierError);
    if (supplierError != null) return;

    final items = <PurchaseLineInput>[];
    for (final line in _lines) {
      if (line.medicineId == null) continue;
      if (line.totalPills <= 0) continue;
      
      final totalLineCost = double.tryParse(line.costController.text) ?? 0;
      final unitCost = totalLineCost / line.totalPills;
      final sellingPrice = double.tryParse(line.sellingPriceController.text);
      
      items.add(PurchaseLineInput(
        medicineId: line.medicineId!,
        medicineName: line.medicineName,
        selectedQuantity: line.totalPills,
        quantity: line.totalPills,
        qtyCarton: line.qtyCarton,
        qtyPack: line.qtyPack,
        qtyStrip: line.qtyStrip,
        qtyPill: line.qtyPill,
        unitName: "Pill",
        unitCost: unitCost,
        sellingPrice: sellingPrice,
        batchNumber:
            line.batchNumberController.text.isEmpty ? null : line.batchNumberController.text,
        expiryDate: line.expiryDate,
      ));
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('أضف سطرًا واحدًا على الأقل')));
      return;
    }

    setState(() => _isSaving = true);
    final ok = await ref.read(purchasesNotifierProvider.notifier).createPurchase(
          supplierId: _supplierId!,
          supplierInvoiceRef: _supplierInvoiceController.text.isEmpty
              ? null
              : _supplierInvoiceController.text,
          items: items,
          paidAmount: double.tryParse(_paidAmountController.text) ?? 0,
          invoiceImagePath: _invoiceImagePath,
        );
    setState(() => _isSaving = false);

    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersNotifierProvider).items;
    final medicines = ref.watch(medicinesNotifierProvider).items;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فاتورة شراء جديدة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.document_scanner),
              tooltip: 'مسح فاتورة بالذكاء الاصطناعي',
              onPressed: _scanInvoiceWithAi,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // حقل اختيار المورد بالبحث الفوري مع أولوية المتعامل معهم
              InkWell(
                onTap: () async {
                  final picked = await SearchableSupplierPicker.show(
                    context,
                    allSuppliers: suppliers,
                    currentSelectedId: _supplierId,
                    onAddNewSupplier: (name, phone) async {
                      await ref.read(suppliersNotifierProvider.notifier).add(name: name, contactInfo: phone);
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _supplierId = picked.id;
                      _supplierError = null;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _supplierError != null ? Colors.red : Colors.grey.shade300,
                      width: _supplierError != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_search_outlined, color: Colors.teal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('المورد / الوكيل *', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              _supplierId != null
                                  ? (suppliers.where((s) => s.id == _supplierId).firstOrNull?.name ?? 'مورد #$_supplierId')
                                  : 'اضغط للبحث واختيار المورد (المتعامل معهم أو الدليل العام)...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _supplierId != null ? FontWeight.bold : FontWeight.normal,
                                color: _supplierId != null ? Colors.black87 : Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              if (_supplierError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(_supplierError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _supplierInvoiceController,
                decoration: const InputDecoration(labelText: 'رقم فاتورة المورد (اختياري)'),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('أصناف الفاتورة', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              ..._lines.asMap().entries.map((entry) {
                final index = entry.key;
                final line = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Autocomplete<int>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return medicines.map((m) => m.id);
                                  }
                                  final query = textEditingValue.text.toLowerCase();
                                  return medicines
                                      .where((m) =>
                                          m.nameAr.toLowerCase().contains(query) ||
                                          (m.nameEn != null && m.nameEn!.toLowerCase().contains(query)))
                                      .map((m) => m.id);
                                },
                                displayStringForOption: (int id) {
                                  try {
                                    return medicines.firstWhere((m) => m.id == id).nameAr;
                                  } catch (_) {
                                    return '';
                                  }
                                },
                                onSelected: (int selectedId) {
                                  setState(() {
                                    final med = medicines.firstWhere((m) => m.id == selectedId);
                                    line.medicineId = selectedId;
                                    line.medicineName = med.nameAr;
                                    line.qtyPerCarton = med.qtyPerCarton;
                                    line.qtyPerPack = med.qtyPerPack;
                                    line.qtyPerStrip = med.qtyPerStrip;
                                    line.medicineType = med.medicineType;
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    onEditingComplete: onEditingComplete,
                                    decoration: InputDecoration(
                                      labelText: 'ابحث عن الدواء',
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.add, color: Colors.blue),
                                        tooltip: 'إضافة دواء جديد',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const MedicineFormScreen()),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: _lines.length > 1 ? () => _removeLine(index) : null,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: line.medicineId == null
                                ? const Text('اختر الدواء أولاً لتحديد الكمية', style: TextStyle(color: Colors.grey))
                                : MultiUnitQuantityWidget(
                                    qtyPerCarton: line.qtyPerCarton,
                                    qtyPerPack: line.qtyPerPack,
                                    qtyPerStrip: line.qtyPerStrip,
                                    medicineType: line.medicineType,
                                    onChanged: (totalPills, cartons, packs, strips, pills) {
                                      setState(() {
                                        line.totalPills = totalPills;
                                        line.qtyCarton = cartons;
                                        line.qtyPack = packs;
                                        line.qtyStrip = strips;
                                        line.qtyPill = pills;
                                      });
                                    },
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: line.costController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'إجمالي تكلفة الشراء (لهذا الصنف)'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: line.sellingPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'سعر بيع الحبة (اختياري)'),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: line.batchNumberController,
                                decoration:
                                    const InputDecoration(labelText: 'رقم الدفعة (اختياري)'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => line.expiryDate = picked);
                              },
                              child: Text(
                                line.expiryDate == null
                                    ? 'تاريخ الصلاحية'
                                    : '${line.expiryDate!.year}-${line.expiryDate!.month}-${line.expiryDate!.day}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('إضافة صنف آخر'),
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي الفاتورة', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${_totalAmount.toStringAsFixed(0)} ريال',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paidAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ المدفوع الآن'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('حفظ الفاتورة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

