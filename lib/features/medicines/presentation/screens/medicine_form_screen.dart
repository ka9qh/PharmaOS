// شاشة إضافة/تعديل دواء
//
// تم إعادة التصميم لتكون احترافية وتشمل الوحدات الثلاث (باكت، شريط، حبة)
// وأسعارها بشكل تلقائي وتفاعلي، تماماً كشاشة إضافة المخزون.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/medicines_provider.dart';
import '../controllers/medicines_controller.dart';
import '../../domain/entities/medicines_entity.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../companies/presentation/providers/companies_provider.dart';
import '../../../suppliers/presentation/providers/suppliers_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/security/role_guard.dart';
import '../../../../core/services/medicine_clinical_helper.dart';
import '../widgets/medicine_clinical_details_dialog.dart';

class MedicineFormScreen extends ConsumerStatefulWidget {
  final MedicineEntity? existing;

  const MedicineFormScreen({super.key, this.existing});

  @override
  ConsumerState<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends ConsumerState<MedicineFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _scientificController;
  late final TextEditingController _unitController;
  
  // الأسعار
  late final TextEditingController _cartonPurchasePriceController;
  late final TextEditingController _cartonSellingPriceController;
  late final TextEditingController _packPurchasePriceController;
  late final TextEditingController _packSellingPriceController;
  late final TextEditingController _stripPurchasePriceController;
  late final TextEditingController _stripSellingPriceController;
  late final TextEditingController _unitPurchasePriceController;
  late final TextEditingController _unitSellingPriceController;

  // التعبئة
  late final TextEditingController _qtyPerCartonController;
  late final TextEditingController _qtyPerPackController;
  late final TextEditingController _qtyPerStripController;
  
  late final TextEditingController _reorderLevelController;
  late final TextEditingController _reserve1Controller;
  late final TextEditingController _reserve2Controller;
  late final TextEditingController _reserve3Controller;

  int? _categoryId;
  int? _companyId;
  int? _supplierId;
  int _medicineType = 1;
  bool _isSaving = false;

  String? _nameError, _purchaseError, _sellingError, _reorderError;

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.nameAr ?? '');
    _nameEnController = TextEditingController(text: e?.nameEn ?? '');
    _scientificController = TextEditingController(text: e?.nameScientific ?? '');
    _unitController = TextEditingController(text: e?.unit ?? 'حبة');
    
    _medicineType = e?.medicineType != 0 ? (e?.medicineType ?? 1) : 1;

    final defaultCartonQty = e?.qtyPerCarton != null
        ? e!.qtyPerCarton.toString()
        : (_medicineType == 2 ? '10' : (_medicineType == 3 ? '12' : (_medicineType == 4 ? '100' : '')));
    _qtyPerCartonController = TextEditingController(text: defaultCartonQty);
    _qtyPerPackController = TextEditingController(text: e?.qtyPerPack != null ? e!.qtyPerPack.toString() : (_medicineType == 2 ? '5' : '1'));
    _qtyPerStripController = TextEditingController(text: e?.qtyPerStrip != null ? e!.qtyPerStrip.toString() : (_medicineType == 1 ? '10' : '1'));

    final packSell = e?.packSellingPrice ?? (e?.sellingPrice ?? 100.0) * (_qtyPerPack() * _qtyPerStrip());
    final packPurch = e?.packPurchasePrice ?? (e?.purchasePrice ?? (packSell * 0.8)) * (_qtyPerPack() * _qtyPerStrip());

    _packSellingPriceController = TextEditingController(text: packSell.toStringAsFixed(0));
    _packPurchasePriceController = TextEditingController(text: packPurch.toStringAsFixed(0));

    final cartonSell = e?.cartonSellingPrice ?? (packSell * (_qtyPerCarton() > 0 ? _qtyPerCarton() : 1));
    final cartonPurch = e?.cartonPurchasePrice ?? (packPurch * (_qtyPerCarton() > 0 ? _qtyPerCarton() : 1));

    _cartonSellingPriceController = TextEditingController(text: cartonSell.toStringAsFixed(0));
    _cartonPurchasePriceController = TextEditingController(text: cartonPurch.toStringAsFixed(0));
    
    _stripPurchasePriceController = TextEditingController();
    _stripSellingPriceController = TextEditingController();
    _unitPurchasePriceController = TextEditingController();
    _unitSellingPriceController = TextEditingController();

    _recalculatePrices();

    _reorderLevelController = TextEditingController(text: e != null ? e.reorderLevel.toString() : '5');
    _reserve1Controller = TextEditingController(text: e?.reserveField1 ?? '');
    _reserve2Controller = TextEditingController(text: e?.reserveField2 ?? '');
    _reserve3Controller = TextEditingController(text: e?.reserveField3 ?? '');
    
    _categoryId = e?.categoryId;
    _companyId = e?.companyId;
    _supplierId = e?.supplierId;
  }

  int _qtyPerCarton() => int.tryParse(_qtyPerCartonController.text) ?? 0;
  int _qtyPerPack() => int.tryParse(_qtyPerPackController.text) ?? 1;
  int _qtyPerStrip() => int.tryParse(_qtyPerStripController.text) ?? 1;

  void _recalculatePrices() {
    if (_medicineType == 2) {
      // إبر وحقن: كرتون + باكت + حبة (إبرة/أمبولة)
      final packSell = double.tryParse(_packSellingPriceController.text) ?? 0;
      final packPurch = double.tryParse(_packPurchasePriceController.text) ?? (packSell * 0.8);
      
      final pillsPerPack = _qtyPerPack() > 0 ? _qtyPerPack() : 1;
      final packsPerCarton = _qtyPerCarton() > 0 ? _qtyPerCarton() : 1;

      final needleSell = pillsPerPack > 0 ? (packSell / pillsPerPack) : packSell;
      final needlePurch = pillsPerPack > 0 ? (packPurch / pillsPerPack) : packPurch;
      final cartonSell = packSell * packsPerCarton;
      final cartonPurch = packPurch * packsPerCarton;

      _unitSellingPriceController.text = needleSell.toStringAsFixed(1);
      _unitPurchasePriceController.text = needlePurch.toStringAsFixed(1);
      _cartonSellingPriceController.text = cartonSell.toStringAsFixed(1);
      _cartonPurchasePriceController.text = cartonPurch.toStringAsFixed(1);
      _stripSellingPriceController.text = needleSell.toStringAsFixed(1);
      _stripPurchasePriceController.text = needlePurch.toStringAsFixed(1);
      _unitController.text = 'حبة (إبرة)';

    } else if (_medicineType == 3) {
      // علب ومعلبات وزجاج ومغذيات: كرتون + علبة
      final cartonSell = double.tryParse(_cartonSellingPriceController.text) ?? 0;
      final cartonPurch = double.tryParse(_cartonPurchasePriceController.text) ?? (cartonSell * 0.8);
      final bottlesPerCarton = _qtyPerCarton() > 0 ? _qtyPerCarton() : 1;

      final bottleSell = bottlesPerCarton > 0 ? (cartonSell / bottlesPerCarton) : cartonSell;
      final bottlePurch = bottlesPerCarton > 0 ? (cartonPurch / bottlesPerCarton) : cartonPurch;

      _unitSellingPriceController.text = bottleSell.toStringAsFixed(1);
      _unitPurchasePriceController.text = bottlePurch.toStringAsFixed(1);
      _packSellingPriceController.text = bottleSell.toStringAsFixed(1);
      _packPurchasePriceController.text = bottlePurch.toStringAsFixed(1);
      _unitController.text = 'علبة';

    } else if (_medicineType == 4) {
      // فراشات وشرنجات: كرتون + حبة
      final cartonSell = double.tryParse(_cartonSellingPriceController.text) ?? 0;
      final cartonPurch = double.tryParse(_cartonPurchasePriceController.text) ?? (cartonSell * 0.8);
      final piecesPerCarton = _qtyPerCarton() > 0 ? _qtyPerCarton() : 1;

      final pieceSell = piecesPerCarton > 0 ? (cartonSell / piecesPerCarton) : cartonSell;
      final piecePurch = piecesPerCarton > 0 ? (cartonPurch / piecesPerCarton) : cartonPurch;

      _unitSellingPriceController.text = pieceSell.toStringAsFixed(1);
      _unitPurchasePriceController.text = piecePurch.toStringAsFixed(1);
      _packSellingPriceController.text = pieceSell.toStringAsFixed(1);
      _packPurchasePriceController.text = piecePurch.toStringAsFixed(1);
      _unitController.text = 'حبة';

    } else {
      // حبوب وأقراص (1)
      final packSell = double.tryParse(_packSellingPriceController.text) ?? 0;
      final packPurch = double.tryParse(_packPurchasePriceController.text) ?? (packSell * 0.8);

      final stripsPerPack = _qtyPerPack();
      final pillsPerStrip = _qtyPerStrip();

      final stripSell = stripsPerPack > 0 ? (packSell / stripsPerPack) : packSell;
      final stripPurch = stripsPerPack > 0 ? (packPurch / stripsPerPack) : packPurch;

      final pillSell = pillsPerStrip > 0 ? (stripSell / pillsPerStrip) : stripSell;
      final pillPurch = pillsPerStrip > 0 ? (stripPurch / pillsPerStrip) : stripPurch;

      final packsPerCarton = _qtyPerCarton() > 0 ? _qtyPerCarton() : 0;
      if (packsPerCarton > 0) {
        _cartonSellingPriceController.text = (packSell * packsPerCarton).toStringAsFixed(1);
        _cartonPurchasePriceController.text = (packPurch * packsPerCarton).toStringAsFixed(1);
      }

      _stripSellingPriceController.text = stripSell.toStringAsFixed(1);
      _stripPurchasePriceController.text = stripPurch.toStringAsFixed(1);
      _unitSellingPriceController.text = pillSell.toStringAsFixed(1);
      _unitPurchasePriceController.text = pillPurch.toStringAsFixed(1);
      _unitController.text = 'حبة';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _scientificController.dispose();
    _unitController.dispose();
    _cartonPurchasePriceController.dispose();
    _cartonSellingPriceController.dispose();
    _packPurchasePriceController.dispose();
    _packSellingPriceController.dispose();
    _stripPurchasePriceController.dispose();
    _stripSellingPriceController.dispose();
    _unitPurchasePriceController.dispose();
    _unitSellingPriceController.dispose();
    _qtyPerCartonController.dispose();
    _qtyPerPackController.dispose();
    _qtyPerStripController.dispose();
    _reorderLevelController.dispose();
    _reserve1Controller.dispose();
    _reserve2Controller.dispose();
    _reserve3Controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = MedicinesController.validate(
      nameAr: _nameController.text,
      purchasePriceText: _unitPurchasePriceController.text,
      sellingPriceText: _unitSellingPriceController.text,
      reorderLevelText: _reorderLevelController.text,
    );
    setState(() {
      _nameError = result.nameError;
      _purchaseError = result.purchasePriceError;
      _sellingError = result.sellingPriceError;
      _reorderError = result.reorderLevelError;
    });
    if (!result.isValid) return;

    setState(() => _isSaving = true);

    final bool ok;
    if (_isEditMode) {
      ok = await ref.read(medicinesNotifierProvider.notifier).updateMedicine(
            widget.existing!.copyWith(
              nameAr: _nameController.text,
              nameEn: _nameEnController.text.isEmpty ? null : _nameEnController.text,
              nameScientific: _scientificController.text.isEmpty ? null : _scientificController.text,
              categoryId: _categoryId,
              companyId: _companyId,
              supplierId: _supplierId,
              unit: _unitController.text,
              purchasePrice: double.parse(_unitPurchasePriceController.text),
              sellingPrice: double.parse(_unitSellingPriceController.text),
              qtyPerCarton: int.tryParse(_qtyPerCartonController.text),
              qtyPerPack: int.tryParse(_qtyPerPackController.text),
              qtyPerStrip: int.tryParse(_qtyPerStripController.text),
              cartonPurchasePrice: double.tryParse(_cartonPurchasePriceController.text),
              cartonSellingPrice: double.tryParse(_cartonSellingPriceController.text),
              packPurchasePrice: double.tryParse(_packPurchasePriceController.text),
              packSellingPrice: double.tryParse(_packSellingPriceController.text),
              stripPurchasePrice: double.tryParse(_stripPurchasePriceController.text),
              stripSellingPrice: double.tryParse(_stripSellingPriceController.text),
              reorderLevel: int.parse(_reorderLevelController.text),
              reserveField1: _reserve1Controller.text,
              reserveField2: _reserve2Controller.text,
              reserveField3: _reserve3Controller.text,
              medicineType: _medicineType,
            ),
          );
    } else {
      ok = await ref.read(medicinesNotifierProvider.notifier).addMedicine(
            nameAr: _nameController.text,
            nameEn: _nameEnController.text.isEmpty ? null : _nameEnController.text,
            nameScientific: _scientificController.text.isEmpty ? null : _scientificController.text,
            categoryId: _categoryId,
            companyId: _companyId,
            supplierId: _supplierId,
            unit: _unitController.text,
            purchasePrice: double.parse(_unitPurchasePriceController.text),
            sellingPrice: double.parse(_unitSellingPriceController.text),
            qtyPerCarton: int.tryParse(_qtyPerCartonController.text),
            qtyPerPack: int.tryParse(_qtyPerPackController.text),
            qtyPerStrip: int.tryParse(_qtyPerStripController.text),
            cartonPurchasePrice: double.tryParse(_cartonPurchasePriceController.text),
            cartonSellingPrice: double.tryParse(_cartonSellingPriceController.text),
            packPurchasePrice: double.tryParse(_packPurchasePriceController.text),
            packSellingPrice: double.tryParse(_packSellingPriceController.text),
            stripPurchasePrice: double.tryParse(_stripPurchasePriceController.text),
            stripSellingPrice: double.tryParse(_stripSellingPriceController.text),
            reorderLevel: int.parse(_reorderLevelController.text),
            reserveField1: _reserve1Controller.text,
            reserveField2: _reserve2Controller.text,
            reserveField3: _reserve3Controller.text,
            medicineType: _medicineType,
          );
    }
    setState(() => _isSaving = false);

    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesNotifierProvider);
    final companiesState = ref.watch(companiesNotifierProvider);
    final suppliersState = ref.watch(suppliersNotifierProvider);
    final currentUser = ref.watch(authNotifierProvider).user;

    final canEditPrice = !_isEditMode || (currentUser?.can(AppPermission.editPrices) ?? false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditMode ? 'تعديل دواء' : 'إضافة دواء جديد')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. المعلومات الأساسية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم العربي *',
                        errorText: _nameError,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameEnController,
                            decoration: const InputDecoration(labelText: 'الاسم الإنجليزي (اختياري)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _scientificController,
                            decoration: const InputDecoration(labelText: 'الاسم العلمي (اختياري)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: categoriesState.items.any((c) => c.id == _categoryId) ? _categoryId : null,
                            decoration: const InputDecoration(labelText: 'التصنيف (اختياري)', border: OutlineInputBorder(), isDense: true),
                            items: categoriesState.items.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                            onChanged: (value) => setState(() => _categoryId = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: companiesState.items.any((c) => c.id == _companyId) ? _companyId : null,
                            decoration: const InputDecoration(labelText: 'الشركة المصنعة (اختياري)', border: OutlineInputBorder(), isDense: true),
                            items: companiesState.items.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                            onChanged: (value) => setState(() => _companyId = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: suppliersState.items.any((s) => s.id == _supplierId) ? _supplierId : null,
                            decoration: const InputDecoration(labelText: 'المورّد (اختياري)', border: OutlineInputBorder(), isDense: true),
                            items: suppliersState.items.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                            onChanged: (value) => setState(() => _supplierId = value),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const Text('2. تصنيف وشكل الدواء:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('حبوب وأقراص'), icon: Icon(Icons.circle_outlined)),
                  ButtonSegment(value: 2, label: Text('إبر وحقن'), icon: Icon(Icons.colorize_outlined)),
                  ButtonSegment(value: 3, label: Text('علب وزجاج ومغذيات'), icon: Icon(Icons.water_drop_outlined)),
                  ButtonSegment(value: 4, label: Text('فراشات وشرنجات'), icon: Icon(Icons.medical_services_outlined)),
                  ButtonSegment(value: 0, label: Text('مراهم وأخرى'), icon: Icon(Icons.more_horiz)),
                ],
                selected: {_medicineType},
                onSelectionChanged: (newSet) {
                  setState(() {
                    _medicineType = newSet.first;
                    if (_medicineType == 2) {
                      if (_qtyPerPackController.text == '1' || _qtyPerPackController.text.isEmpty) {
                        _qtyPerPackController.text = '5';
                      }
                      if (_qtyPerCartonController.text.isEmpty) {
                        _qtyPerCartonController.text = '10';
                      }
                    } else if (_medicineType == 3) {
                      if (_qtyPerCartonController.text.isEmpty) {
                        _qtyPerCartonController.text = '12';
                      }
                    } else if (_medicineType == 4) {
                      if (_qtyPerCartonController.text.isEmpty) {
                        _qtyPerCartonController.text = '100';
                      }
                    }
                    _recalculatePrices();
                  });
                },
              ),

              const SizedBox(height: 24),
              const Text('3. التعبئة والتسعير (محاسبة ذكية تلقائية):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    if (!canEditPrice)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'تعديل السعر يتطلب صلاحية "تعديل الأسعار" - غير متاحة لحسابك',
                          style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),

                    // 1. واجهة الحبوب والأقراص (1)
                    if (_medicineType == 1) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _qtyPerPackController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'كم شريط داخل الباكت؟', border: OutlineInputBorder(), isDense: true),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _qtyPerStripController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'كم حبة داخل الشريط؟', border: OutlineInputBorder(), isDense: true),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _qtyPerCartonController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'كم باكت داخل الكرتون؟ (اختياري)', border: OutlineInputBorder(), isDense: true),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _packPurchasePriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر شراء الباكت', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _packSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع الباكت', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _stripSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع الشريط (تلقائي)', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _unitSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع الحبة (تلقائي)', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // 2. واجهة الإبر والحقن (2): كرتون + باكت + حبة إبرة
                    if (_medicineType == 2) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _qtyPerCartonController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'كم باكت داخل الكرتون؟', border: OutlineInputBorder(), isDense: true),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _qtyPerPackController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'كم حبة/إبرة داخل الباكت؟', border: OutlineInputBorder(), isDense: true),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _packPurchasePriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر شراء الباكت', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _packSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع الباكت', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _unitSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع الحبة (الإبرة) تلقائي', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _cartonSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع الكرتون (تلقائي)', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // 3. واجهة أدوية العلب والمعلبات وزجاج ومغذيات (3): كرتون + علبة
                    if (_medicineType == 3) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _qtyPerCartonController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'كم علبة/زجاجة داخل الكرتون؟', border: OutlineInputBorder(), isDense: true),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cartonPurchasePriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر شراء الكرتون', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _cartonSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع الكرتون', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _unitPurchasePriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر شراء العلبة (تلقائي)', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _unitSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع العلبة (تلقائي)', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // 4. واجهة الفراشات والشرنجات والمستلزمات (4): كرتون + حبة
                    if (_medicineType == 4) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _qtyPerCartonController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'كم حبة داخل الكرتون؟', border: OutlineInputBorder(), isDense: true),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cartonPurchasePriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر شراء الكرتون', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _cartonSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع الكرتون', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                              onChanged: (_) => _recalculatePrices(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _unitPurchasePriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر شراء الحبة (تلقائي)', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _unitSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر بيع الحبة (تلقائي)', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // 5. مراهم وأصناف عامة (0)
                    if (_medicineType == 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _unitPurchasePriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر الشراء', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _unitSellingPriceController,
                              enabled: canEditPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'سعر البيع', border: OutlineInputBorder(), isDense: true, suffixText: 'ر.ي'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text('4. إعدادات أخرى:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _reorderLevelController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'حد التنبيه لنقص المخزون', errorText: _reorderError, border: const OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _reserve1Controller, decoration: const InputDecoration(labelText: 'دواعي الاستعمال / الوصفة الطبية', border: OutlineInputBorder(), isDense: true))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _reserve2Controller, decoration: const InputDecoration(labelText: 'حقل إضافي 2', border: OutlineInputBorder(), isDense: true))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _reserve3Controller, decoration: const InputDecoration(labelText: 'حقل إضافي 3', border: OutlineInputBorder(), isDense: true))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('5. الوصفة الطبية والجرعات السريرية المعتمدة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  if (_isEditMode && widget.existing != null)
                    TextButton.icon(
                      onPressed: () => MedicineClinicalDetailsDialog.show(
                        context,
                        medicineId: widget.existing!.id,
                        fallbackName: _nameController.text,
                      ),
                      icon: const Icon(Icons.preview_outlined, size: 18),
                      label: const Text('معاينة بطاقة الوصفة والبدائل الكاملة'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final profile = MedicineClinicalHelper.getFullClinicalProfile(
                    medicineName: _nameController.text,
                    scientificName: _scientificController.text,
                    rawReserve1: _reserve1Controller.text,
                  );

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.teal),
                            const SizedBox(width: 6),
                            Text('جرعة البالغين (Adult Dosage):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal.shade900)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(profile.prescription.adultDosage, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.child_care, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text('جرعة الأطفال (Pediatric Dosage):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(profile.prescription.pediatricDosage, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.health_and_safety_outlined, size: 16, color: Colors.indigo),
                            const SizedBox(width: 6),
                            Text('طريقة الاستخدام والإرشادات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo.shade900)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(profile.prescription.instructions, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_isEditMode ? 'حفظ التعديلات' : 'حفظ الصنف', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

