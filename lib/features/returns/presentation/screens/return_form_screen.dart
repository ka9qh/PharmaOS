import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/returns_entity.dart';
import '../providers/returns_provider.dart';
import '../../../cash_register/presentation/providers/cash_register_provider.dart';
import '../../../medicines/presentation/providers/medicines_provider.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../../core/widgets/multi_unit_quantity_widget.dart';

class ReturnFormScreen extends ConsumerStatefulWidget {
  final bool isSaleReturn;
  final SaleItemLookup? saleItem;
  final PurchaseItemLookup? purchaseItem;
  final VoidCallback onReturnSuccess;

  const ReturnFormScreen({
    super.key,
    required this.isSaleReturn,
    this.saleItem,
    this.purchaseItem,
    required this.onReturnSuccess,
  });

  @override
  ConsumerState<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends ConsumerState<ReturnFormScreen> {
  int _qtyCartons = 0;
  int _qtyPacks = 0;
  int _qtyStrips = 0;
  int _qtyPills = 0;
  int _totalPills = 0;
  final _reasonController = TextEditingController();
  
  String _settlementMethod = 'refund'; // 'refund', 'deduction'
  String _paymentMethod = 'نقدي'; // 'نقدي', 'محفظة'
  int? _walletId;
  
  String? _quantityError;
  MedicineEntity? _medicineEntity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final medicineId = widget.isSaleReturn ? widget.saleItem!.medicineId : widget.purchaseItem!.medicineId;
      final medicines = ref.read(medicinesNotifierProvider).items;
      setState(() {
        _medicineEntity = medicines.firstWhere((m) => m.id == medicineId);
      });
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() async {
    final maxReturnable = widget.isSaleReturn ? widget.saleItem!.maxReturnable : widget.purchaseItem!.maxReturnable;
    
    final baseQty = _totalPills;
    
    if (baseQty <= 0 || baseQty > maxReturnable) {
      setState(() => _quantityError = 'الكمية غير صحيحة. الأقصى: $maxReturnable حبة (أساسي)');
      return;
    }
    setState(() => _quantityError = null);

    final unitPrice = widget.isSaleReturn ? widget.saleItem!.unitPrice : widget.purchaseItem!.unitCost;
    final refundAmount = unitPrice * baseQty;

    bool ok = false;
    if (widget.isSaleReturn) {
      ok = await ref.read(returnsNotifierProvider.notifier).submitCustomerReturn(
        saleItemId: widget.saleItem!.saleItemId,
        quantity: baseQty, // الكمية التي تُخصم من المخزون وتعود
        qtyCarton: _qtyCartons,
        qtyPack: _qtyPacks,
        qtyStrip: _qtyStrips,
        qtyPill: _qtyPills,
        refundAmount: refundAmount,
        settlementMethod: _settlementMethod,
        paymentMethod: _paymentMethod,
        walletId: _walletId,
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
      );
    } else {
      ok = await ref.read(returnsNotifierProvider.notifier).submitVendorReturn(
        purchaseItemId: widget.purchaseItem!.purchaseItemId,
        quantity: baseQty,
        qtyCarton: _qtyCartons,
        qtyPack: _qtyPacks,
        qtyStrip: _qtyStrips,
        qtyPill: _qtyPills,
        refundAmount: refundAmount,
        settlementMethod: _settlementMethod,
        paymentMethod: _paymentMethod,
        walletId: _walletId,
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
      );
    }

    if (ok && mounted) {
      widget.onReturnSuccess();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isSaleReturn ? 'إرجاع مبيعات (عميل)' : 'إرجاع مشتريات (مورد)';
    final itemName = widget.isSaleReturn ? widget.saleItem!.medicineName : widget.purchaseItem!.medicineName;
    final maxReturnable = widget.isSaleReturn ? widget.saleItem!.maxReturnable : widget.purchaseItem!.maxReturnable;
    final unitPrice = widget.isSaleReturn ? widget.saleItem!.unitPrice : widget.purchaseItem!.unitCost;
    
    final wallets = ref.watch(cashRegisterProvider).wallets;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(leading: const BackButton(), title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الدواء: $itemName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('الحد الأقصى للإرجاع من هذه الفاتورة: $maxReturnable وحدة', style: const TextStyle(color: Colors.blue)),
              Text('السعر للوحدة: $unitPrice ر.ي'),
              const Divider(),
              const SizedBox(height: 16),
              
              if (_medicineEntity != null)
                MultiUnitQuantityWidget(
                  qtyPerCarton: _medicineEntity!.qtyPerCarton,
                  qtyPerPack: _medicineEntity!.qtyPerPack,
                  qtyPerStrip: _medicineEntity!.qtyPerStrip,
                  onChanged: (pills, cartons, packs, strips, remainderPills) {
                    setState(() {
                      _totalPills = pills;
                      _qtyCartons = cartons;
                      _qtyPacks = packs;
                      _qtyStrips = strips;
                      _qtyPills = remainderPills;
                    });
                  },
                ),
              if (_quantityError != null) ...[
                const SizedBox(height: 4),
                Text(_quantityError!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              
              const Text('طريقة التسوية المالية:', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Radio<String>(
                    value: 'refund',
                    groupValue: _settlementMethod,
                    onChanged: (val) => setState(() => _settlementMethod = val!),
                  ),
                  const Text('إرجاع نقدي/محفظة'),
                  const SizedBox(width: 24),
                  Radio<String>(
                    value: 'deduction',
                    groupValue: _settlementMethod,
                    onChanged: (val) => setState(() => _settlementMethod = val!),
                  ),
                  Text(widget.isSaleReturn ? 'خصم من دين العميل' : 'خصم من دين المورد'),
                ],
              ),
              
              if (_settlementMethod == 'refund') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'نقدي', child: Text('نقدي (صندوق الكاش)')),
                    DropdownMenuItem(value: 'محفظة', child: Text('محفظة رقمية')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _paymentMethod = val!;
                      if (_paymentMethod == 'نقدي') _walletId = null;
                    });
                  },
                ),
                if (_paymentMethod == 'محفظة') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _walletId,
                    decoration: const InputDecoration(labelText: 'اختر المحفظة', border: OutlineInputBorder()),
                    items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                    onChanged: (val) => setState(() => _walletId = val),
                  ),
                ],
              ],
              
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب الإرجاع (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              
              const Spacer(),
              
              // Total Preview
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي المرتجع:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '${(_totalPills * unitPrice).toStringAsFixed(0)} ر.ي',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('تأكيد العملية', style: TextStyle(fontSize: 18)),
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
