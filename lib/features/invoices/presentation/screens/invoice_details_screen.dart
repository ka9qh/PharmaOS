// شاشة تفاصيل الفاتورة الشاملة، المرتجعات، السداد، والطباعة - PharmaOS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:drift/drift.dart' hide Column;
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../../returns/domain/repositories/returns_repository.dart';
import '../../../customers/domain/repositories/customers_repository.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/repositories/invoices_repository.dart';
import '../providers/invoices_provider.dart';
import '../../../../core/security/role_guard.dart';
import '../../../../features/pos/presentation/providers/pos_provider.dart';
import 'package:go_router/go_router.dart';

class InvoiceDetailsScreen extends ConsumerStatefulWidget {
  final int invoiceId;
  final String? invoiceNumber;
  final String? invoiceType;
  final InvoiceEntity? invoice;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
    this.invoiceNumber,
    this.invoiceType,
    this.invoice,
  });

  @override
  ConsumerState<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends ConsumerState<InvoiceDetailsScreen> {
  InvoiceEntity? _loadedInvoice;
  bool _isLoadingInvoice = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadInvoice();
  }

  Future<void> _checkAndLoadInvoice({bool forceReload = false}) async {
    if (widget.invoice != null && !forceReload && _loadedInvoice == null) {
      setState(() => _loadedInvoice = widget.invoice);
      if (widget.invoice!.isExpense || widget.invoice!.linkedReturns.isNotEmpty) {
        return;
      }
    }
    setState(() => _isLoadingInvoice = true);
    try {
      final repo = sl<InvoicesRepository>();
      InvoiceEntity? match;

      final effectiveType = (widget.invoiceType ?? _loadedInvoice?.type ?? widget.invoice?.type)?.toUpperCase();
      final effectiveNumber = widget.invoiceNumber ?? _loadedInvoice?.invoiceNumber ?? widget.invoice?.invoiceNumber;
      final effectiveId = (_loadedInvoice?.id ?? widget.invoice?.id ?? widget.invoiceId);

      if (effectiveType == 'PURCHASE') {
        final purchases = await repo.searchPurchaseInvoices();
        match = purchases.where((i) {
          if (effectiveNumber != null && effectiveNumber.isNotEmpty) {
            return i.invoiceNumber.toLowerCase() == effectiveNumber.toLowerCase();
          }
          return i.id == effectiveId;
        }).firstOrNull;
      } else if (effectiveType == 'SALE') {
        final sales = await repo.searchSalesInvoices();
        match = sales.where((i) {
          if (effectiveNumber != null && effectiveNumber.isNotEmpty) {
            return i.invoiceNumber.toLowerCase() == effectiveNumber.toLowerCase();
          }
          return i.id == effectiveId;
        }).firstOrNull;
      } else if (effectiveType == 'EXPENSE') {
        final expenses = await repo.searchExpenseInvoices();
        match = expenses.where((i) {
          if (effectiveNumber != null && effectiveNumber.isNotEmpty) {
            return i.invoiceNumber.toLowerCase() == effectiveNumber.toLowerCase();
          }
          return i.id == effectiveId;
        }).firstOrNull;
      } else if (effectiveType == 'CUSTOMER_RETURN' || effectiveType == 'VENDOR_RETURN' || effectiveType == 'RETURN') {
        final returns = await repo.searchReturnInvoices();
        match = returns.where((i) {
          if (effectiveNumber != null && effectiveNumber.isNotEmpty) {
            return i.invoiceNumber.toLowerCase() == effectiveNumber.toLowerCase();
          }
          return i.id == effectiveId;
        }).firstOrNull;
      }

      // 2. إذا لم نجدها أو لم يكن النوع محدداً، ابحث برقم الفاتورة النصي المميز
      if (match == null && effectiveNumber != null && effectiveNumber.isNotEmpty) {
        final all = await repo.searchAllInvoices(query: effectiveNumber);
        match = all.where((i) => i.invoiceNumber.toLowerCase() == effectiveNumber.toLowerCase()).firstOrNull;
      }

      // 3. كحل أخير، ابحث بالمعرف الرقمي في كافة الفواتير
      if (match == null && effectiveId > 0) {
        final all = await repo.searchAllInvoices();
        match = all.where((i) => i.id == effectiveId).firstOrNull;
      }

      if (match != null && mounted) {
        setState(() => _loadedInvoice = match);
      }
    } catch (e) {
      debugPrint('Error loading invoice details: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInvoice = false);
    }
  }

  String _formatSettlementMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'refund':
        return 'استرداد نقدي فوري';
      case 'debt':
        return 'خصم من المديونية / الحساب';
      case 'wallet':
        return 'إيداع بالمحفظة';
      case 'replacement':
        return 'تعويض ببضاعة بديلة';
      default:
        return method ?? 'استرداد نقدي';
    }
  }

  // 1. تنفيذ مرتجع شامل متعدد الوحدات لصنف أو كامل الفاتورة
  void _showReturnDialog(InvoiceEntity inv, InvoiceItemEntity? specificItem) {
    if (inv.status == 'returned' || inv.status == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('⚠️ هذه الفاتورة مسترجعة بالكامل بالفعل ولا يمكن عمل مرتجع إضافي لها.'),
        ),
      );
      return;
    }

    RoleGuard.checkPermission(
      context: context,
      ref: ref,
      permission: AppPermission.voidInvoice,
      onGranted: () async {
        InvoiceItemEntity selectedItem = specificItem ?? inv.items.first;

        // وحدة الإرجاع المختارة
        String selectedUnitType = 'pack'; // 'carton', 'pack', 'strip', 'pill'
        final qtyController = TextEditingController(text: '1');
        final reasonController = TextEditingController(text: inv.isSale ? 'مرتجع حسب طلب العميل' : 'إرجاع بضاعة للمورد');
        String settlementMethod = 'refund'; // 'refund', 'wallet', 'debt', 'replacement'
        final repBatchController = TextEditingController();
        DateTime? repExpiryDate;

        await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              // حساب المعاملات والكميات
              int multiplier = 1;
              if (selectedUnitType == 'carton') {
                multiplier = selectedItem.calculatedPillsPerCarton;
              } else if (selectedUnitType == 'pack') {
                multiplier = selectedItem.calculatedPillsPerPack;
              } else if (selectedUnitType == 'strip') {
                multiplier = selectedItem.calculatedPillsPerStrip;
              } else {
                multiplier = 1;
              }

              final enteredCount = int.tryParse(qtyController.text) ?? 0;
              final totalPillsToReturn = enteredCount * multiplier;
              final maxPills = selectedItem.quantity;
              final isValidQty = totalPillsToReturn > 0 && totalPillsToReturn <= maxPills;

              // حساب مبلغ الاسترداد بدقة
              final unitCost = (selectedItem.quantity > 0) ? (selectedItem.subtotal / selectedItem.quantity) : selectedItem.unitPrice;
              final calculatedRefundAmount = unitCost * totalPillsToReturn;

              // الوحدات المتاحة للصنف
              List<DropdownMenuItem<String>> unitOptions = [];
              if (selectedItem.qtyPerCarton > 1 || selectedItem.cartonPurchaseCost > 0) {
                unitOptions.add(DropdownMenuItem(
                  value: 'carton',
                  child: Text('كرتون (${selectedItem.calculatedPillsPerCarton} حبة)'),
                ));
              }
              unitOptions.add(DropdownMenuItem(
                value: 'pack',
                child: Text('باكت / عبوة (${selectedItem.calculatedPillsPerPack} حبة)'),
              ));
              if (selectedItem.medicineType == 1 && selectedItem.calculatedPillsPerStrip > 1) {
                unitOptions.add(DropdownMenuItem(
                  value: 'strip',
                  child: Text('شريط (${selectedItem.calculatedPillsPerStrip} حبة)'),
                ));
              }
              unitOptions.add(const DropdownMenuItem(
                value: 'pill',
                child: Text('حبة / وحدة مفردة'),
              ));

              // التأكد من أن القيمة المختارة موجودة
              if (!unitOptions.any((o) => o.value == selectedUnitType)) {
                selectedUnitType = unitOptions.first.value!;
              }

              return Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          inv.isSale ? Icons.assignment_return_outlined : Icons.keyboard_return_rounded,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          specificItem != null
                              ? 'إرجاع صنف: ${specificItem.medicineName}'
                              : (inv.isSale ? 'عمل مرتجع مبيعات' : 'عمل مرتجع مشتريات للمورد'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: SizedBox(
                      width: 520,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (specificItem == null) ...[
                            const Text('اختر الصنف المراد إرجاعه من الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<InvoiceItemEntity>(
                              value: selectedItem,
                              isExpanded: true,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: inv.items.map((it) {
                                return DropdownMenuItem(
                                  value: it,
                                  child: Text('${it.medicineName}  (المتوفر بالفاتورة: ${it.displayQuantityWithUnits})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedItem = val;
                                    qtyController.text = '1';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          // تفاصيل الصنف الإجمالية
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blueGrey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'الصنف: ${selectedItem.medicineName}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'إجمالي الكمية بالفاتورة: ${selectedItem.displayQuantityWithUnits} (${selectedItem.quantity} حبة)',
                                        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blueGrey.shade300),
                                  ),
                                  child: Text(
                                    selectedItem.displayUnitPriceWithUnit,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // اختيار الوحدة والكمية
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('وحدة الإرجاع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: selectedUnitType,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      items: unitOptions,
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedUnitType = val);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('الكمية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: qtyController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onChanged: (_) => setDialogState(() {}),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ملخص الحسبة في الوقت الفعلي
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isValidQty ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isValidQty ? Colors.green.shade300 : Colors.red.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'إجمالي الكمية الأساسية: $totalPillsToReturn من أصل $maxPills حبة',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isValidQty ? Colors.green.shade900 : Colors.red.shade900,
                                      ),
                                    ),
                                    if (!isValidQty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'الكمية المدخلة تتجاوز الكمية الموجودة في الفاتورة!',
                                        style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                                      ),
                                    ],
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('المبلغ المسترد:', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                    Text(
                                      '${calculatedRefundAmount.toStringAsFixed(0)} ر.ي',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isValidQty ? Colors.green.shade800 : Colors.red.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // طريقة التسوية / الاسترداد (خصوصاً للموردين)
                          if (!inv.isSale) ...[
                            const Text('طريقة تسوية المرتجع مع المورد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: settlementMethod,
                              isExpanded: true,
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'refund', child: Text('استرداد نقدي فوري (نقداً للخزينة)')),
                                DropdownMenuItem(value: 'debt', child: Text('خصم وتخفيض من مديونية المورد (آجل)')),
                                DropdownMenuItem(value: 'wallet', child: Text('إيداع في المحفظة / حساب الصيدلية')),
                                DropdownMenuItem(value: 'replacement', child: Text('تعويض ببضاعة بديلة')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => settlementMethod = val);
                                }
                              },
                            ),
                            if (settlementMethod == 'replacement') ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.purple.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.autorenew, color: Colors.purple.shade800, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          'بيانات الدفعة البديلة المستلمة من المورد:',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade900),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: repBatchController,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'رقم التشغيلة الجديدة',
                                              hintText: 'Batch No.',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: repExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                                                firstDate: DateTime.now(),
                                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                                              );
                                              if (picked != null) {
                                                setDialogState(() => repExpiryDate = picked);
                                              }
                                            },
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                isDense: true,
                                                labelText: 'تاريخ الصلاحية الجديد',
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: Text(
                                                repExpiryDate != null
                                                    ? DateFormat('yyyy-MM-dd').format(repExpiryDate!)
                                                    : 'اختر التاريخ 📅',
                                                style: TextStyle(fontSize: 12, color: repExpiryDate != null ? Colors.black87 : Colors.grey),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'ℹ️ سيتم إدخال الدفعة البديلة للمخزون فوراً بنفس كمية وتكلفة المرتجع ($totalPillsToReturn حبة)',
                                      style: TextStyle(fontSize: 11, color: Colors.purple.shade800),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 14),
                          ],

                          const Text('سبب الإرجاع / ملاحظات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: reasonController,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'اكتب سبب الإرجاع هنا...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                    if (specificItem == null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
                        icon: const Icon(Icons.assignment_return),
                        label: const Text('مرتجع كلي للفاتورة'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _processFullReturn(inv, reasonController.text);
                        },
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: isValidQty ? Colors.orange.shade800 : Colors.grey),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('تأكيد المرتجع وضبط المخزون'),
                      onPressed: !isValidQty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _processUnitReturn(
                                inv: inv,
                                item: selectedItem,
                                unitType: selectedUnitType,
                                unitCount: enteredCount,
                                totalPills: totalPillsToReturn,
                                refundAmount: calculatedRefundAmount,
                                settlementMethod: settlementMethod,
                                reason: reasonController.text,
                                replacementBatchNumber: repBatchController.text.trim(),
                                replacementExpiryDate: repExpiryDate,
                                replacementTotalPills: totalPillsToReturn,
                              );
                            },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _processFullReturn(InvoiceEntity inv, String reason) async {
    final isSale = inv.type == 'SALE';
    try {
      final returnsRepo = sl<ReturnsRepository>();
      for (final item in inv.items) {
        if (isSale) {
          await returnsRepo.createCustomerReturn(
            saleItemId: item.id,
            quantity: item.quantity,
            qtyCarton: item.qtyCarton,
            qtyPack: item.qtyPack,
            qtyStrip: item.qtyStrip,
            qtyPill: item.qtyPill,
            refundAmount: item.subtotal,
            settlementMethod: 'refund',
            paymentMethod: inv.paymentMethod,
            reason: reason,
          );
        } else {
          await returnsRepo.createVendorReturn(
            purchaseItemId: item.id,
            quantity: item.quantity,
            qtyCarton: item.qtyCarton,
            qtyPack: item.qtyPack,
            qtyStrip: item.qtyStrip,
            qtyPill: item.qtyPill,
            refundAmount: item.subtotal,
            settlementMethod: 'refund',
            paymentMethod: inv.paymentMethod,
            reason: reason,
          );
        }
      }

      ref.read(invoicesProvider.notifier).loadInvoices();
      await _checkAndLoadInvoice(forceReload: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: const Text('✓ تم تسجيل المرتجع الكلي للفاتورة بنجاح وتحديث حركة المخزون.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تسجيل المرتجع: $e')),
        );
      }
    }
  }

  Future<void> _processUnitReturn({
    required InvoiceEntity inv,
    required InvoiceItemEntity item,
    required String unitType,
    required int unitCount,
    required int totalPills,
    required double refundAmount,
    required String settlementMethod,
    required String reason,
    String? replacementBatchNumber,
    DateTime? replacementExpiryDate,
    int? replacementTotalPills,
  }) async {
    final isSale = inv.type == 'SALE';

    int carton = (unitType == 'carton') ? unitCount : 0;
    int pack = (unitType == 'pack') ? unitCount : 0;
    int strip = (unitType == 'strip') ? unitCount : 0;
    int pill = (unitType == 'pill') ? unitCount : 0;

    try {
      final returnsRepo = sl<ReturnsRepository>();

      if (isSale) {
        await returnsRepo.createCustomerReturn(
          saleItemId: item.id,
          quantity: totalPills,
          qtyCarton: carton,
          qtyPack: pack,
          qtyStrip: strip,
          qtyPill: pill,
          refundAmount: refundAmount,
          settlementMethod: 'refund',
          paymentMethod: inv.paymentMethod,
          reason: reason,
        );
      } else {
        await returnsRepo.createVendorReturn(
          purchaseItemId: item.id,
          quantity: totalPills,
          qtyCarton: carton,
          qtyPack: pack,
          qtyStrip: strip,
          qtyPill: pill,
          refundAmount: refundAmount,
          settlementMethod: settlementMethod,
          paymentMethod: inv.paymentMethod,
          reason: reason,
        );

        // إذا كانت التسوية تعويض ببضاعة بديلة، إدخال الدفعة البديلة للمخزون
        if (settlementMethod == 'replacement' && (replacementBatchNumber?.isNotEmpty ?? false)) {
          final db = sl<AppDatabase>();
          final unitCost = (item.quantity > 0) ? (item.subtotal / item.quantity) : item.unitPrice;
          await db.into(db.batches).insert(
            BatchesCompanion.insert(
              medicineId: item.medicineId,
              batchNumber: Value(replacementBatchNumber),
              expiryDate: Value(replacementExpiryDate),
              quantity: replacementTotalPills ?? totalPills,
              purchasePrice: unitCost,
            ),
          );
        }
      }

      // تحديث قائمة الفواتير
      ref.read(invoicesProvider.notifier).loadInvoices();
      await _checkAndLoadInvoice(forceReload: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(settlementMethod == 'replacement'
                ? '✓ تم تسجيل المرتجع وإدخال الدفعة البديلة للمخزون بنجاح ($unitCount $unitType من ${item.medicineName}).'
                : '✓ تم تسجيل المرتجع بنجاح ($unitCount $unitType من ${item.medicineName}) وتحديث المخزون.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تسجيل المرتجع: $e')),
        );
      }
    }
  }

  Future<void> _editInvoice(InvoiceEntity inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل الفاتورة'),
          content: const Text(
            'سيتم عمل مرتجع كلي للفاتورة الحالية لضبط المخزون والحسابات، ثم فتح محتوياتها كمسودة جديدة لتعديلها. هل تود المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              icon: const Icon(Icons.edit_document),
              label: const Text('متابعة التعديل'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // 1. Process full return to restore stock and logs
    await _processFullReturn(inv, 'تصحيح فاتورة');

    // 2. Load the items into POS
    await ref.read(posNotifierProvider.notifier).loadInvoiceForEditing(inv);

    if (mounted) {
      // 3. Navigate to POS
      GoRouter.of(context).go('/pos');
    }
  }

  // 2. تسديد أو دفع باقي الفاتورة الآجلة
  Future<void> _showPayDebtDialog(InvoiceEntity inv) async {
    final remaining = inv.remainingAmount;
    final amountController = TextEditingController(text: remaining.toStringAsFixed(0));
    final noteController = TextEditingController(text: 'سداد دفعة من الفاتورة رقم ${inv.invoiceNumber}');

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.payment, color: Colors.green),
              SizedBox(width: 8),
              Text('تسديد دفعة من الفاتورة الآجلة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المبلغ المتبقي على الفاتورة: ${remaining.toStringAsFixed(0)} ر.ي',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 14),
              const Text('المبلغ المدفوع الآن:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  suffixText: 'ر.ي',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('ملاحظات وسند القبض:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('تأكيد السداد والقبض'),
              onPressed: () async {
                final paid = double.tryParse(amountController.text) ?? 0;
                if (paid <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                await _processPayment(inv, paid, noteController.text);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(InvoiceEntity inv, double amount, String notes) async {
    try {
      final db = sl<AppDatabase>();

      if (inv.isPurchase) {
        final p = await (db.select(db.purchases)..where((tbl) => tbl.id.equals(inv.id))).getSingleOrNull();
        if (p != null) {
          final newPaid = (p.paidAmount + amount).clamp(0.0, p.totalAmount);
          await (db.update(db.purchases)..where((tbl) => tbl.id.equals(inv.id))).write(
            PurchasesCompanion(paidAmount: Value(newPaid)),
          );
        }
      } else if (inv.isSale) {
        final s = await (db.select(db.sales)..where((tbl) => tbl.id.equals(inv.id))).getSingleOrNull();
        if (s != null && s.customerId != null) {
          try {
            await sl<CustomersRepository>().recordPayment(
              customerId: s.customerId!,
              amount: amount,
              notes: notes,
            );
          } catch (_) {}
        }
      }

      await ref.read(invoicesProvider.notifier).loadInvoices();
      await _checkAndLoadInvoice();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text('✓ تم تسجيل سداد مبلغ ${amount.toStringAsFixed(0)} ر.ي بنجاح وتحديث الفاتورة.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تسجيل السداد: $e')),
        );
      }
    }
  }

  // 3. طباعة الفاتورة حرارياً أو A4 أو سند صرف مصروف
  Future<void> _printInvoice(InvoiceEntity inv) async {
    final pdf = pw.Document();
    final isSale = inv.type == 'SALE';
    final isExpense = inv.isExpense;

    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    if (isExpense) {
      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 160 * PdfPageFormat.mm, marginAll: 5 * PdfPageFormat.mm),
          theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('PharmaOS - صيدليتي', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text('سند صرف نقدية ومصروفات', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('رقم السند: ${inv.invoiceNumber}', style: const pw.TextStyle(fontSize: 9)),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('التاريخ والوقت:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(inv.date), style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('بند المصروف:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(inv.category ?? inv.items.firstOrNull?.medicineName ?? 'مصروف', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المستفيد / الساحب:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(inv.partyName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('طريقة الصرف:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(inv.paymentMethod, style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  if (inv.recorderName != null && inv.recorderName!.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المحاسب المسجل:', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(inv.recorderName!, style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                  if (inv.reason != null && inv.reason!.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('البيان / ملاحظات:', style: const pw.TextStyle(fontSize: 8)),
                        pw.Expanded(
                          child: pw.Text(inv.reason!, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.left),
                        ),
                      ],
                    ),
                  ],
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المبلغ المصروف:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${inv.totalAmount.toStringAsFixed(0)} ر.ي', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('توقيع المستلم: ...........', style: const pw.TextStyle(fontSize: 7)),
                      pw.Text('توقيع المحاسب: ...........', style: const pw.TextStyle(fontSize: 7)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text('توقيع المسؤول / المدير: ...........', style: const pw.TextStyle(fontSize: 7)),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('PharmaOS - صيدليتي', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    inv.isCustomerReturn
                        ? 'مرتجع مبيعات'
                        : (inv.isVendorReturn
                            ? 'مرتجع مشتريات'
                            : (isSale ? 'فاتورة مبيعات' : 'فاتورة مشتريات')),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text('رقم الفاتورة: ${inv.invoiceNumber}', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('التاريخ: ${DateFormat("yyyy-MM-dd HH:mm").format(inv.date)}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('${isSale ? "العميل" : "المورد"}: ${inv.partyName}', style: const pw.TextStyle(fontSize: 8)),
                  if (inv.originalInvoiceRef != null && inv.originalInvoiceRef!.isNotEmpty)
                    pw.Text('أصل الفاتورة: ${inv.originalInvoiceRef}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Divider(),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.2),
                      2: const pw.FlexColumnWidth(1.2),
                      3: const pw.FlexColumnWidth(1.0),
                      4: const pw.FlexColumnWidth(1.1),
                    },
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Text('الصنف', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('الكمية', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('الصلاحية', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('السعر', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('الإجمالي', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      ...inv.items.map((it) {
                        final expStr = it.expiryDate != null ? DateFormat('yy-MM-dd').format(it.expiryDate!) : '-';
                        return pw.TableRow(
                          children: [
                            pw.Text(it.medicineName, style: const pw.TextStyle(fontSize: 7)),
                            pw.Text(it.displayQuantityWithUnits, style: const pw.TextStyle(fontSize: 7)),
                            pw.Text(expStr, style: const pw.TextStyle(fontSize: 7)),
                            pw.Text(it.displayUnitPriceWithUnit, style: const pw.TextStyle(fontSize: 7)),
                            pw.Text(it.subtotal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7)),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('الإجمالي العام:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${inv.totalAmount.toStringAsFixed(0)} ر.ي', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (inv.discount > 0)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الخصم:', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('${inv.discount.toStringAsFixed(0)} ر.ي', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  pw.SizedBox(height: 6),
                  pw.Text('شكراً لتعاملكم معنا ونتمنى لكم دوام الصحة والعافية', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseVoucher(InvoiceEntity inv) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // كارت السند المالي الرئيسي
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_long, color: Colors.redAccent, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inv.invoiceName ?? 'سند صرف مصروف',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'رقم السند: ${inv.invoiceNumber}',
                                    style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          inv.paymentMethod,
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(Icons.calendar_today_outlined, 'تاريخ وتوقيت الصرف', DateFormat('yyyy-MM-dd HH:mm').format(inv.date)),
                  _buildDetailRow(Icons.category_outlined, 'بند المصروف', inv.category ?? inv.items.firstOrNull?.medicineName ?? 'مصروف عام'),
                  _buildDetailRow(Icons.person_outline, 'المستفيد / الساحب', inv.partyName),
                  if (inv.recorderName != null && inv.recorderName!.isNotEmpty)
                    _buildDetailRow(Icons.badge_outlined, 'المحاسب المسؤول', inv.recorderName!),
                  if (inv.walletName != null && inv.walletName!.isNotEmpty)
                    _buildDetailRow(Icons.account_balance_wallet_outlined, 'الخزينة / المحفظة', inv.walletName!),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text('بيان وتفاصيل سند الصرف المالي:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // جدول بنود الصرف
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.monetization_on_outlined, color: Colors.red),
                            SizedBox(width: 8),
                            Text('المبلغ المصروف:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                          '${inv.totalAmount.toStringAsFixed(0)} ر.ي',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  if (inv.reason != null && inv.reason!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تفاصيل البيان والملاحظات المسجلة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text(inv.reason!, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // كارت التوقيعات والاعتمادات الرسمية
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الاعتمادات والتوقيعات الرسمية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('توقيع المستلم / الساحب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          const SizedBox(height: 6),
                          Text(inv.partyName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 12),
                          const Text('..............................', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('توقيع أمين الخزينة / المحاسب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          const SizedBox(height: 6),
                          Text(inv.recorderName ?? 'المحاسب', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 12),
                          const Text('..............................', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const Column(
                        children: [
                          Text('توقيع المدير المسؤول', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          SizedBox(height: 6),
                          Text('الإدارة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          SizedBox(height: 12),
                          Text('..............................', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInvoice) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = ref.watch(invoicesProvider);
    InvoiceEntity? candidate = _loadedInvoice ?? widget.invoice;

    if (candidate == null) {
      final type = widget.invoiceType?.toUpperCase();
      final num = widget.invoiceNumber?.toLowerCase();

      if (type == 'PURCHASE') {
        candidate = state.purchaseInvoices.where((i) => (num != null && i.invoiceNumber.toLowerCase() == num) || i.id == widget.invoiceId).firstOrNull;
      } else if (type == 'SALE') {
        candidate = state.salesInvoices.where((i) => (num != null && i.invoiceNumber.toLowerCase() == num) || i.id == widget.invoiceId).firstOrNull;
      } else if (type == 'EXPENSE') {
        candidate = state.expenseInvoices.where((i) => (num != null && i.invoiceNumber.toLowerCase() == num) || i.id == widget.invoiceId).firstOrNull;
      } else if (type == 'CUSTOMER_RETURN' || type == 'VENDOR_RETURN' || type == 'RETURN') {
        candidate = state.returnInvoices.where((i) => (num != null && i.invoiceNumber.toLowerCase() == num) || i.id == widget.invoiceId).firstOrNull;
      }

      if (candidate == null && num != null && num.isNotEmpty) {
        candidate = state.allInvoices.where((i) => i.invoiceNumber.toLowerCase() == num).firstOrNull;
      }

      candidate ??= state.allInvoices.where((i) => i.id == widget.invoiceId).firstOrNull ??
          state.salesInvoices.where((i) => i.id == widget.invoiceId).firstOrNull ??
          state.purchaseInvoices.where((i) => i.id == widget.invoiceId).firstOrNull ??
          state.returnInvoices.where((i) => i.id == widget.invoiceId).firstOrNull ??
          state.expenseInvoices.where((i) => i.id == widget.invoiceId).firstOrNull;
    }

    if (candidate == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الفاتورة')),
        body: const Center(child: Text('لم يتم العثور على بيانات الفاتورة')),
      );
    }

    final inv = candidate;

    final isSale = inv.isSale;
    final isPurchase = inv.isPurchase;
    final isReturn = inv.isReturn;
    final isExpense = inv.isExpense;
    final isReturnedStatus = inv.status == 'returned' || inv.status == 'cancelled';
    final isPartiallyReturned = inv.status == 'partially_returned';
    final canReturn = !isReturn && !isExpense && !isReturnedStatus;
    final hasDebt = inv.remainingAmount > 0 && !isReturn && !isExpense && !isReturnedStatus;

    // تلوين وهوية الفاتورة
    Color themeColor;
    IconData headerIcon;
    String titlePrefix;

    if (inv.isCustomerReturn) {
      titlePrefix = 'مرتجع مبيعات';
      themeColor = Colors.amber.shade800;
      headerIcon = Icons.assignment_return;
    } else if (inv.isVendorReturn) {
      titlePrefix = 'مرتجع مشتريات';
      themeColor = Colors.purple.shade800;
      headerIcon = Icons.keyboard_return;
    } else if (inv.isExpense) {
      titlePrefix = 'سند صرف مصروف';
      themeColor = const Color(0xFF991B1B);
      headerIcon = Icons.receipt_long;
    } else if (inv.isSale) {
      titlePrefix = 'فاتورة مبيعات';
      themeColor = const Color(0xFF0D9488);
      headerIcon = Icons.point_of_sale;
    } else {
      titlePrefix = 'فاتورة مشتريات وتوريد';
      themeColor = const Color(0xFF1E40AF);
      headerIcon = Icons.inventory_2;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(headerIcon, size: 20),
              const SizedBox(width: 8),
              Text('$titlePrefix: ${inv.invoiceNumber}'),
            ],
          ),
          actions: [
            if (isSale && canReturn)
              IconButton(
                icon: const Icon(Icons.edit_document),
                tooltip: 'تعديل الفاتورة',
                onPressed: () => _editInvoice(inv),
              ),
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: isExpense ? 'طباعة سند الصرف' : 'طباعة الفاتورة',
              onPressed: () => _printInvoice(inv),
            ),
            if (canReturn)
              IconButton(
                icon: const Icon(Icons.assignment_return_outlined),
                tooltip: 'عمل مرتجع',
                onPressed: () => _showReturnDialog(inv, null),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isExpense ? const Color(0xFF991B1B) : const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.print),
                  label: Text(isExpense ? 'طباعة سند الصرف' : 'طباعة الفاتورة'),
                  onPressed: () => _printInvoice(inv),
                ),
              ),
              if (canReturn) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800, padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.assignment_return),
                    label: const Text('عمل مرتجع'),
                    onPressed: () => _showReturnDialog(inv, null),
                  ),
                ),
              ],
              if (hasDebt) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.payment),
                    label: const Text('سداد باقي الفاتورة'),
                    onPressed: () => _showPayDebtDialog(inv),
                  ),
                ),
              ],
            ],
          ),
        ),
        body: isExpense
            ? _buildExpenseVoucher(inv)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بنر التنبيه في حالة المرتجع الكلي أو الجزئي
                    if (isReturnedStatus) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade800, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🔴 تم عمل مرتجع كلي لهذه الفاتورة (مسترجعة بالكامل)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'تم استرجاع أصناف هذه الفاتورة وإلغاء أرصدتها وضبط قيود المخزون.',
                                    style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isPartiallyReturned) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade400, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '⚠️ فاتورة تحتوي على مرتجع جزئي',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'تم تسجيل مرتجع لبعض الأصناف من هذه الفاتورة مسبقاً، يمكنك مراجعة فواتير المرتجعات بالأسفل.',
                                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // قسم فواتير المرتجعات المرتبطة بهذه الفاتورة مع إمكانية الانتقال المباشر إليها
                    if (inv.linkedReturns.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.shade300, width: 1.5),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.history_rounded, color: Colors.deepOrange, size: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'فواتير المرتجعات المسجلة من هذه الفاتورة (${inv.linkedReturns.length}):',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...inv.linkedReturns.map((ret) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.assignment_return_outlined, size: 18, color: Colors.deepOrange),
                                            const SizedBox(width: 6),
                                            Text(
                                              'رقم المرتجع: ${ret.returnNumber}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                            ),
                                          ],
                                        ),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.deepOrange,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(Icons.open_in_new, size: 14),
                                          label: const Text('عرض فاتورة المرتجع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => InvoiceDetailsScreen(
                                                  invoiceId: ret.returnId,
                                                  invoiceNumber: ret.returnNumber,
                                                  invoiceType: ret.returnType,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Text('📅 التاريخ: ${DateFormat("yyyy-MM-dd HH:mm").format(ret.returnDate)}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                        Text('💳 طريقة التسوية: ${_formatSettlementMethod(ret.settlementMethod)}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                        Text('💰 إجمالي المسترد: ${ret.totalAmount.toStringAsFixed(0)} ر.ي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                                      ],
                                    ),
                                    if (ret.reason != null && ret.reason!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('📝 السبب: ${ret.reason}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                    ],
                                    if (ret.items.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      const Text('الأصناف المرتجعة بالتفصيل:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: ret.items.map((it) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.orange.shade100),
                                            ),
                                            child: Text(
                                              '• ${it.medicineName}: ${it.formattedQuantity} (${it.subtotal.toStringAsFixed(0)} ر.ي)',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    // كارت ملخص الفاتورة المميز حسب النوع
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            // شريط علوي ملون لهوية الفاتورة
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.12),
                                border: Border(bottom: BorderSide(color: themeColor.withValues(alpha: 0.2))),
                              ),
                              child: Row(
                                children: [
                                  Icon(headerIcon, color: themeColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    inv.isCustomerReturn
                                        ? '🔄 فاتورة مرتجع مبيعات رسمية (استرجاع من عميل للمخزون)'
                                        : (inv.isVendorReturn
                                            ? '↩️ فاتورة مرتجع مشتريات رسمية (إرجاع لمورد من المخزون)'
                                            : (inv.isPurchase
                                                ? '📦 فاتورة توريد ومشتريات مخزنية'
                                                : '🛍️ فاتورة مبيعات معتمدة')),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeColor),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      inv.paymentMethod,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: themeColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            inv.invoiceName ?? inv.invoiceNumber,
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'الرقم المرجعي: ${inv.invoiceNumber}',
                                            style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${inv.totalAmount.toStringAsFixed(0)} ر.ي',
                                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeColor),
                                          ),
                                          if (inv.isReturn)
                                            const Text(
                                              'إجمالي قيمة المرتجع',
                                              style: TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('📅 التاريخ: ${DateFormat("yyyy-MM-dd HH:mm").format(inv.date)}'),
                                      Text('👤 ${isSale || inv.isCustomerReturn ? "العميل" : "المورد"}: ${inv.partyName}'),
                                    ],
                                  ),
                                  if (inv.originalInvoiceRef != null && inv.originalInvoiceRef!.isNotEmpty) ...[
                                     const SizedBox(height: 10),
                                     InkWell(
                                       onTap: () {
                                         Navigator.push(
                                           context,
                                           MaterialPageRoute(
                                             builder: (_) => InvoiceDetailsScreen(
                                               invoiceId: inv.originalInvoiceId ?? 0,
                                               invoiceNumber: inv.originalInvoiceNumber ?? inv.originalInvoiceRef,
                                               invoiceType: inv.originalInvoiceType ?? (inv.isCustomerReturn ? 'SALE' : 'PURCHASE'),
                                             ),
                                           ),
                                         );
                                       },
                                       borderRadius: BorderRadius.circular(10),
                                       child: Container(
                                         width: double.infinity,
                                         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                         decoration: BoxDecoration(
                                           color: Colors.deepOrange.shade50,
                                           borderRadius: BorderRadius.circular(10),
                                           border: Border.all(color: Colors.deepOrange.shade300, width: 1.2),
                                         ),
                                         child: Row(
                                           children: [
                                             Container(
                                               padding: const EdgeInsets.all(6),
                                               decoration: BoxDecoration(
                                                 color: Colors.deepOrange.shade100,
                                                 borderRadius: BorderRadius.circular(8),
                                               ),
                                               child: const Icon(Icons.link, size: 18, color: Colors.deepOrange),
                                             ),
                                             const SizedBox(width: 10),
                                             Expanded(
                                               child: Column(
                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                 children: [
                                                   Text(
                                                     'أصل الفاتورة المسترجع منها: ${inv.originalInvoiceRef}',
                                                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange),
                                                   ),
                                                   const Text(
                                                     'اضغط هنا للانتقال مباشرة إلى تفاصيل الفاتورة الأصلية ومطابقة الأصناف',
                                                     style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                             const SizedBox(width: 8),
                                             FilledButton.tonalIcon(
                                               style: FilledButton.styleFrom(
                                                 backgroundColor: Colors.deepOrange.shade700,
                                                 foregroundColor: Colors.white,
                                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                 minimumSize: Size.zero,
                                                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                               ),
                                               icon: const Icon(Icons.arrow_forward, size: 16),
                                               label: const Text('فتح الفاتورة الأصلية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                               onPressed: () {
                                                 Navigator.push(
                                                   context,
                                                   MaterialPageRoute(
                                                     builder: (_) => InvoiceDetailsScreen(
                                                       invoiceId: inv.originalInvoiceId ?? 0,
                                                       invoiceNumber: inv.originalInvoiceNumber ?? inv.originalInvoiceRef,
                                                       invoiceType: inv.originalInvoiceType ?? (inv.isCustomerReturn ? 'SALE' : 'PURCHASE'),
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
                                  if (inv.reason != null && inv.reason!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.notes, size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text('سبب الإرجاع / الملاحظات: ${inv.reason}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          inv.isCustomerReturn
                              ? 'الأصناف المسترجعة من العميل إلى المخزون:'
                              : (inv.isVendorReturn
                                  ? 'الأصناف المرتجعة للمورد من المخزون:'
                                  : (isSale
                                      ? 'الأصناف المباعة للعميل وبيانات الصلاحية والمورد:'
                                      : 'الأصناف الموردة للمخزون وتسعيرة الوحدات الكاملة:')),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        if (canReturn)
                          Text(
                            '(اضغط على أيقونة الإرجاع لإرجاع صنف محدد)',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // قائمة وبطاقات الأصناف
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: inv.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = inv.items[index];

                          // حساب مدة وتاريخ الصلاحية
                          int? daysUntilExpiry;
                          if (item.expiryDate != null) {
                            daysUntilExpiry = item.expiryDate!.difference(DateTime.now()).inDays;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: themeColor.withValues(alpha: 0.1),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: themeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.medicineName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          if (item.companyName != null && item.companyName!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'الشركة المصنعة: ${item.companyName}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${item.subtotal.toStringAsFixed(0)} ر.ي',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.blueGrey),
                                        ),
                                        if (canReturn) ...[
                                          const SizedBox(height: 4),
                                          IconButton(
                                            icon: const Icon(Icons.assignment_return_outlined, color: Colors.orange, size: 22),
                                            tooltip: 'إرجاع هذا الصنف فقط',
                                            onPressed: () => _showReturnDialog(inv, item),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // شارات الكمية وسعر الوحدة المباشر
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.teal.shade200),
                                      ),
                                      child: Text(
                                        'الكمية: ${item.displayQuantityWithUnits}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.teal.shade900,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.indigo.shade200),
                                      ),
                                      child: Text(
                                        'سعر الوحدة: ${item.displayUnitPriceWithUnit}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.indigo.shade900,
                                        ),
                                      ),
                                    ),

                                    // شارة تاريخ الصلاحية البارزة
                                    if (item.expiryDate != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (daysUntilExpiry != null && daysUntilExpiry <= 0)
                                              ? Colors.red.shade50
                                              : ((daysUntilExpiry != null && daysUntilExpiry <= 90)
                                                  ? Colors.amber.shade50
                                                  : Colors.green.shade50),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: (daysUntilExpiry != null && daysUntilExpiry <= 0)
                                                ? Colors.red.shade400
                                                : ((daysUntilExpiry != null && daysUntilExpiry <= 90)
                                                    ? Colors.amber.shade400
                                                    : Colors.green.shade400),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              (daysUntilExpiry != null && daysUntilExpiry <= 0)
                                                  ? Icons.error_outline
                                                  : Icons.event_available,
                                              size: 14,
                                              color: (daysUntilExpiry != null && daysUntilExpiry <= 0)
                                                  ? Colors.red.shade800
                                                  : ((daysUntilExpiry != null && daysUntilExpiry <= 90)
                                                      ? Colors.amber.shade900
                                                      : Colors.green.shade900),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              (daysUntilExpiry != null && daysUntilExpiry <= 0)
                                                  ? 'منتهي الصلاحية: ${DateFormat('yyyy-MM-dd').format(item.expiryDate!)}'
                                                  : ((daysUntilExpiry != null && daysUntilExpiry <= 90)
                                                      ? 'ينتهي قريباً: ${DateFormat('yyyy-MM-dd').format(item.expiryDate!)} (متبقي $daysUntilExpiry يوم)'
                                                      : 'الصلاحية: ${DateFormat('yyyy-MM-dd').format(item.expiryDate!)}'),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: (daysUntilExpiry != null && daysUntilExpiry <= 0)
                                                    ? Colors.red.shade900
                                                    : ((daysUntilExpiry != null && daysUntilExpiry <= 90)
                                                        ? Colors.amber.shade900
                                                        : Colors.green.shade900),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // شارة رقم التشغيلة
                                    if (item.batchNumber != null && item.batchNumber!.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blueGrey.shade200),
                                        ),
                                        child: Text(
                                          '🏷️ تشغيلة: ${item.batchNumber}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],

                                    // شارة المورد (في فواتير المبيعات والمشتريات والمرتجع)
                                    if (item.supplierName != null && item.supplierName!.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.indigo.shade200),
                                        ),
                                        child: Text(
                                          '🏢 المورد: ${item.supplierName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // صندوق تفصيل أسعار الشراء والبيع لجميع الوحدات (مهم جداً في فواتير المشتريات)
                                if (isPurchase || item.packPurchaseCost > 0) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.calculate_outlined, size: 16, color: Colors.blueGrey),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'تفصيل تسعيرة جميع الوحدات (شراء وبيع):',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                            ),
                                            const Spacer(),
                                            Text(
                                              'التعبئة: ${item.qtyPerCarton} باكت/كرتون | ${item.qtyPerPack} شريط/باكت | ${item.qtyPerStrip} حبة/شريط',
                                              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 14),
                                        Row(
                                          children: [
                                            // أسعار التكلفة والشراء
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('🛒 أسعار الشراء والتكلفة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo)),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 12,
                                                    runSpacing: 4,
                                                    children: [
                                                      if (item.cartonPurchaseCost > 0 && item.qtyPerCarton > 1)
                                                        Text('كرتون: ${item.cartonPurchaseCost.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 11)),
                                                      Text('باكت: ${item.packPurchaseCost.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                      if (item.medicineType == 1)
                                                        Text('شريط: ${item.stripPurchaseCost.toStringAsFixed(1)} ر.ي', style: const TextStyle(fontSize: 11)),
                                                      Text('حبة: ${item.pillPurchaseCost.toStringAsFixed(1)} ر.ي', style: const TextStyle(fontSize: 11)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(width: 1, height: 36, color: Colors.grey.shade300),
                                            const SizedBox(width: 12),
                                            // أسعار البيع للجمهور
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('🏷️ أسعار البيع المحددة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 12,
                                                    runSpacing: 4,
                                                    children: [
                                                      if (item.cartonSellingPrice > 0 && item.qtyPerCarton > 1)
                                                        Text('كرتون: ${item.cartonSellingPrice.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 11)),
                                                      Text('باكت: ${item.packSellingPrice.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                      if (item.medicineType == 1)
                                                        Text('شريط: ${item.stripSellingPrice.toStringAsFixed(1)} ر.ي', style: const TextStyle(fontSize: 11)),
                                                      Text('حبة: ${item.pillSellingPrice.toStringAsFixed(1)} ر.ي', style: const TextStyle(fontSize: 11)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // الإجماليات والديون
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الإجمالي العام:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(
                                  '${inv.totalAmount.toStringAsFixed(0)} ر.ي',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isSale ? Colors.green : (isPurchase ? Colors.blue.shade800 : Colors.blueGrey),
                                  ),
                                ),
                              ],
                            ),
                            if (inv.discount > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('الخصم الممنوح:'),
                                  Text('${inv.discount.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: Colors.red)),
                                ],
                              ),
                            ],
                            if (inv.paidAmount != null) ...[
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('المبلغ المسدد / المدفوع:'),
                                  Text('${inv.paidAmount!.toStringAsFixed(0)} ر.ي', style: const TextStyle(color: Colors.green)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(isSale ? 'المتبقي (دين على العميل):' : 'المتبقي (دين على الصيدلية للمورد):',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    '${inv.remainingAmount.toStringAsFixed(0)} ر.ي',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }
}
