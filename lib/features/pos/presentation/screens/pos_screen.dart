// شاشة نقطة البيع (POS) المتقدمة - PharmaOS
// تدعم: قراءة الباركود، البحث اليدوي مع اختيار وحدات البيع (باكت/شريط/حبة)،
// الدفع النقدي، الدفع عبر المحافظ الإلكترونية، الدفع الآجل مع إضافة العميل فورياً،
// والخصومات، وحساب الباقي، والطباعة الفورية.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/pos_provider.dart';
import '../controllers/pos_controller.dart';
import '../widgets/pos_widget.dart';
import '../widgets/manual_add_dialog.dart';
import '../widgets/pos_returns_dialog.dart';
import '../widgets/bind_unrecognized_barcode_dialog.dart';
import '../widgets/clinical_interaction_banner.dart';
import '../widgets/smart_alternatives_dialog.dart';
import '../../../customers/presentation/providers/customers_provider.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../../../core/di/service_locator.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../ai/presentation/screens/ai_chat_screen.dart';
import '../../../medicines/presentation/screens/wanted_medicines_screen.dart';
import '../../../../core/widgets/floating_ai_assistant.dart';
import '../../../../core/widgets/searchable_entity_picker.dart';
import '../../../../core/database/app_database.dart';
import '../../../doctors/presentation/providers/doctors_provider.dart';
import '../../../prescriptions/presentation/providers/prescriptions_provider.dart';
import '../../../prescriptions/presentation/screens/tele_consultation_dialog.dart';
import '../../../sales/domain/repositories/sales_repository.dart';
import '../../domain/entities/pos_entity.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  final _discountController = TextEditingController(text: '0');
  final _amountReceivedController = TextEditingController();
  String? _discountError;
  int? _selectedWalletId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(posNotifierProvider.notifier).refreshStats();
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _discountController.dispose();
    _amountReceivedController.dispose();
    super.dispose();
  }

  Future<void> _submitBarcode(String value) async {
    final barcode = value.trim();
    if (barcode.isEmpty) return;

    final medicines = await sl<MedicinesRepository>().getAll(searchQuery: barcode);
    final medicine = medicines.where((m) => m.barcode == barcode).firstOrNull ??
        medicines.where((m) => m.sku == barcode).firstOrNull ??
        medicines.firstOrNull;

    if (medicine == null) {
      _barcodeController.clear();
      final boundMedicine = await BindUnrecognizedBarcodeDialog.show(
        context,
        scannedBarcode: barcode,
      );

      if (boundMedicine != null && mounted) {
        await showManualAddToCartDialog(
          context,
          initialMedicine: boundMedicine,
          onAdd: (med, qty, unitName, multiplier, unitPrice) {
            ref.read(posNotifierProvider.notifier).addMedicineWithQuantity(med, qty, unitName, multiplier, unitPrice);
            _barcodeFocusNode.requestFocus();
          },
        );
      } else {
        _barcodeFocusNode.requestFocus();
      }
      return;
    }

    _barcodeController.clear();

    if (mounted) {
      await showManualAddToCartDialog(
        context,
        initialMedicine: medicine,
        onAdd: (med, qty, unitName, multiplier, unitPrice) {
          ref.read(posNotifierProvider.notifier).addMedicineWithQuantity(med, qty, unitName, multiplier, unitPrice);
          _barcodeFocusNode.requestFocus();
        },
      );
    } else {
      _barcodeFocusNode.requestFocus();
    }
  }

  void _showAddNewCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue),
              SizedBox(width: 8),
              Text('إضافة عميل جديد للبيع الآجل'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل (إلزامي)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final ok = await ref.read(customersNotifierProvider.notifier).add(
                      name: name,
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    );
                if (ok && mounted) {
                  Navigator.pop(ctx);
                  final updatedCustomers = ref.read(customersNotifierProvider).items;
                  final newCustomer = updatedCustomers.where((c) => c.name == name).firstOrNull;
                  if (newCustomer != null) {
                    ref.read(posNotifierProvider.notifier).setCustomer(newCustomer.id, newCustomer.name);
                  }
                }
              },
              child: const Text('حفظ واختيار'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuspendDialog() {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعليق الفاتورة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هل تريد تعليق الفاتورة الحالية لإكمالها لاحقاً؟'),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة مرجعية (اختياري)',
                  hintText: 'مثلاً: العميل ذهب للصراف',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final ok = await ref.read(posNotifierProvider.notifier).suspendCurrentSale(noteCtrl.text.trim());
                if (ok && mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تعليق الفاتورة بنجاح'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('تعليق'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuspendedSalesDialog() async {
    final suspendedSales = await sl<SalesRepository>().getSuspendedSales();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('الفواتير المعلقة'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: suspendedSales.isEmpty
                ? const Center(child: Text('لا توجد فواتير معلقة حالياً'))
                : ListView.separated(
                    itemCount: suspendedSales.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final sale = suspendedSales[index];
                      // Format the date nicely
                      final dt = DateTime.parse(sale['createdAt']).toLocal();
                      final timeStr = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        leading: const Icon(Icons.pause_circle_outline, color: Colors.amber),
                        title: Text(sale['referenceNote']?.toString().isEmpty ?? true ? 'بدون ملاحظة' : sale['referenceNote']),
                        subtitle: Text('الوقت: $timeStr'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore, color: Colors.blue),
                              tooltip: 'استرجاع الفاتورة',
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await ref.read(posNotifierProvider.notifier).loadSuspendedSale(sale);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'حذف التعليق',
                              onPressed: () async {
                                await sl<SalesRepository>().deleteSuspendedSale(sale['id']);
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  _showSuspendedSalesDialog(); // reload
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  String _formatDiscount(double value) {
    if (value <= 0) return '';
    return 'خصم: ${value.toStringAsFixed(0)} ر.ي';
  }

  void _showUnitChangeDialog(BuildContext context, WidgetRef ref, CartItem item) async {
    final medRepo = sl<MedicinesRepository>();
    final medicine = await medRepo.getById(item.medicineId);
    if (medicine == null || !context.mounted) return;

    final qtyPerCarton = (medicine.qtyPerCarton != null && medicine.qtyPerCarton! > 0) ? medicine.qtyPerCarton! : 1;
    final qtyPerPack = (medicine.qtyPerPack != null && medicine.qtyPerPack! > 0) ? medicine.qtyPerPack! : 1;
    final qtyPerStrip = (medicine.qtyPerStrip != null && medicine.qtyPerStrip! > 0) ? medicine.qtyPerStrip! : 1;
    final pillPrice = medicine.sellingPrice > 0 ? medicine.sellingPrice : 10.0;

    final packPrice = (medicine.packSellingPrice != null && medicine.packSellingPrice! > 0)
        ? medicine.packSellingPrice!
        : (medicine.medicineType == 2 ? pillPrice * qtyPerPack : pillPrice * qtyPerPack * qtyPerStrip);

    final stripPrice = (medicine.stripSellingPrice != null && medicine.stripSellingPrice! > 0)
        ? medicine.stripSellingPrice!
        : (pillPrice * qtyPerStrip);

    final cartonPrice = (medicine.cartonSellingPrice != null && medicine.cartonSellingPrice! > 0)
        ? medicine.cartonSellingPrice!
        : (medicine.medicineType == 3 || medicine.medicineType == 4
            ? pillPrice * qtyPerCarton
            : packPrice * qtyPerCarton);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تغيير وحدة البيع: ${medicine.nameAr}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (medicine.medicineType == 2) ...[
                  // إبر وحقن: كرتون + باكت + حبة (إبرة)
                  ListTile(
                    leading: const Icon(Icons.archive_outlined, color: Colors.blue),
                    title: Text('كرتون ($qtyPerCarton باكت = ${qtyPerCarton * qtyPerPack} إبرة)'),
                    subtitle: Text('السعر: $cartonPrice ر.ي'),
                    onTap: () {
                      ref.read(posNotifierProvider.notifier).changeItemUnit(
                        item.medicineId,
                        item.selectedUnitMultiplier,
                        'كرتون',
                        qtyPerCarton * qtyPerPack,
                        cartonPrice,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined, color: Colors.blue),
                    title: Text('باكت ($qtyPerPack إبرة)'),
                    subtitle: Text('السعر: $packPrice ر.ي'),
                    onTap: () {
                      ref.read(posNotifierProvider.notifier).changeItemUnit(
                        item.medicineId,
                        item.selectedUnitMultiplier,
                        'باكت',
                        qtyPerPack,
                        packPrice,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.colorize_outlined, color: Colors.blue),
                    title: const Text('حبة (إبرة واحدة)'),
                    subtitle: Text('السعر: $pillPrice ر.ي'),
                    onTap: () {
                      ref.read(posNotifierProvider.notifier).changeItemUnit(
                        item.medicineId,
                        item.selectedUnitMultiplier,
                        'حبة',
                        1,
                        pillPrice,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ] else if (medicine.medicineType == 3) ...[
                  // علب ومعلبات وزجاج ومغذيات: كرتون + علبة
                  ListTile(
                    leading: const Icon(Icons.archive_outlined, color: Colors.blue),
                    title: Text('كرتون ($qtyPerCarton علبة)'),
                    subtitle: Text('السعر: $cartonPrice ر.ي'),
                    onTap: () {
                      ref.read(posNotifierProvider.notifier).changeItemUnit(
                        item.medicineId,
                        item.selectedUnitMultiplier,
                        'كرتون',
                        qtyPerCarton,
                        cartonPrice,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.water_drop_outlined, color: Colors.blue),
                    title: const Text('علبة واحدة'),
                    subtitle: Text('السعر: $pillPrice ر.ي'),
                    onTap: () {
                      ref.read(posNotifierProvider.notifier).changeItemUnit(
                        item.medicineId,
                        item.selectedUnitMultiplier,
                        'علبة',
                        1,
                        pillPrice,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ] else if (medicine.medicineType == 4) ...[
                  // فراشات وشرنجات: كرتون + حبة
                  ListTile(
                    leading: const Icon(Icons.archive_outlined, color: Colors.blue),
                    title: Text('كرتون ($qtyPerCarton حبة)'),
                    subtitle: Text('السعر: $cartonPrice ر.ي'),
                    onTap: () {
                      ref.read(posNotifierProvider.notifier).changeItemUnit(
                        item.medicineId,
                        item.selectedUnitMultiplier,
                        'كرتون',
                        qtyPerCarton,
                        cartonPrice,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.medical_services_outlined, color: Colors.blue),
                    title: const Text('حبة واحدة'),
                    subtitle: Text('السعر: $pillPrice ر.ي'),
                    onTap: () {
                      ref.read(posNotifierProvider.notifier).changeItemUnit(
                        item.medicineId,
                        item.selectedUnitMultiplier,
                        'حبة',
                        1,
                        pillPrice,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ] else ...[
                  // حبوب وأقراص (1)
                  if (medicine.qtyPerCarton != null && medicine.qtyPerCarton! > 0)
                    ListTile(
                      leading: const Icon(Icons.archive_outlined, color: Colors.blue),
                      title: Text('كرتون ($qtyPerCarton باكت = ${qtyPerCarton * qtyPerPack * qtyPerStrip} حبة)'),
                      subtitle: Text('السعر: $cartonPrice ر.ي'),
                      onTap: () {
                        ref.read(posNotifierProvider.notifier).changeItemUnit(
                          item.medicineId,
                          item.selectedUnitMultiplier,
                          'كرتون',
                          qtyPerCarton * qtyPerPack * qtyPerStrip,
                          cartonPrice,
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined, color: Colors.blue),
                    title: Text('باكت (${qtyPerPack * qtyPerStrip} حبة)'),
                    subtitle: Text('السعر: $packPrice ر.ي'),
                    onTap: () {
                      ref.read(posNotifierProvider.notifier).changeItemUnit(
                        item.medicineId,
                        item.selectedUnitMultiplier,
                        'باكت',
                        qtyPerPack * qtyPerStrip,
                        packPrice,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                  if (qtyPerStrip > 1)
                    ListTile(
                      leading: const Icon(Icons.view_headline, color: Colors.blue),
                      title: Text('شريط ($qtyPerStrip حبة)'),
                      subtitle: Text('السعر: $stripPrice ر.ي'),
                      onTap: () {
                        ref.read(posNotifierProvider.notifier).changeItemUnit(
                          item.medicineId,
                          item.selectedUnitMultiplier,
                          'شريط',
                          qtyPerStrip,
                          stripPrice,
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.circle, size: 14, color: Colors.blue),
                    title: const Text('حبة (1 حبة)'),
                    subtitle: Text('السعر: $pillPrice ر.ي'),
                    onTap: () {
                      ref.read(posNotifierProvider.notifier).changeItemUnit(
                        item.medicineId,
                        item.selectedUnitMultiplier,
                        'حبة',
                        1,
                        pillPrice,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAlternativesDialog(BuildContext context, CartItem item) async {
    final medRepo = sl<MedicinesRepository>();
    final medicine = await medRepo.getById(item.medicineId);
    if (medicine == null || !context.mounted) return;

    final selectedAlt = await SmartAlternativesDialog.show(
      context,
      targetMedicine: medicine,
    );

    if (selectedAlt != null && mounted) {
      ref.read(posNotifierProvider.notifier).removeItem(item.medicineId, item.selectedUnitMultiplier);
      await showManualAddToCartDialog(
        context,
        initialMedicine: selectedAlt,
        onAdd: (med, qty, unitName, multiplier, unitPrice) {
          ref.read(posNotifierProvider.notifier).addMedicineWithQuantity(med, qty, unitName, multiplier, unitPrice);
          _barcodeFocusNode.requestFocus();
        },
      );
    }
  }

  Future<void> _checkout() async {
    final state = ref.read(posNotifierProvider);
    final error = PosController.validateDiscount(_discountController.text, state.subtotal);
    setState(() => _discountError = error);
    if (error != null) return;

    ref.read(posNotifierProvider.notifier).setDiscount(
          _discountController.text.trim().isEmpty ? 0 : double.parse(_discountController.text),
        );

    final ok = await ref.read(posNotifierProvider.notifier).checkout();
    if (ok && mounted) {
      final completedState = ref.read(posNotifierProvider);
      await showDialog(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                ),
                const SizedBox(width: 10),
                const Text('تمت عملية البيع بنجاح'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رقم الفاتورة: ${completedState.lastCompletedInvoice}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'الإجمالي: ${completedState.lastCompletedTotal?.toStringAsFixed(0)} ريال',
                  style: const TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.bold),
                ),
                if ((completedState.lastCompletedChange ?? 0) > 0)
                  Text(
                    'المبلغ المتبقي للعميل: ${completedState.lastCompletedChange!.toStringAsFixed(0)} ريال',
                    style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                if (state.isCreditSale)
                  Text(
                    'العميل المدين: ${state.selectedCustomerName}',
                    style: const TextStyle(fontSize: 13, color: Colors.purple),
                  ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'المساعد الصيدلاني الذكي (AI)',
                icon: const Icon(Icons.smart_toy_outlined, color: Colors.teal),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiChatScreen()),
                  );
                },
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تم'),
              ),
            ],
          ),
        ),
      );
      _discountController.text = '0';
      _amountReceivedController.clear();
      _barcodeFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posNotifierProvider);
    final walletsAsync = ref.watch(walletsNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 6,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('المساعد الصيدلاني (AI)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => FloatingAiDialog.show(context),
        ),
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'لوحة التحكم وبقية الشاشات',
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go('/dashboard');
              }
            },
          ),
          title: const Text('نقطة البيع (POS)'),
          actions: [
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                foregroundColor: const Color(0xFF6366F1),
              ),
              icon: const Icon(Icons.wifi_channel_rounded),
              label: const Text('استشارة المدير / قراءة روشتة', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => TeleConsultationDialog.show(
                context,
                onAddSuggestedMedicineToCart: (medName) => _submitBarcode(medName),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade50, foregroundColor: Colors.deepOrange),
              icon: const Icon(Icons.keyboard_return),
              label: const Text('مرتجعات', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                await showDialog(context: context, builder: (_) => const POSReturnsDialog());
                ref.read(posNotifierProvider.notifier).refreshStats();
              },
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange.shade50),
              icon: const Icon(Icons.add_alert_outlined, color: Colors.deepOrange),
              label: const Text('تسجيل علاج ناقص / طلب عميل', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WantedMedicinesScreen()),
              ),
            ),
            const SizedBox(width: 8),
            if (state.items.isNotEmpty)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade100, foregroundColor: Colors.brown),
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('تعليق الفاتورة'),
                onPressed: _showSuspendDialog,
              ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade900),
              icon: const Icon(Icons.list_alt),
              label: const Text('الفواتير المعلقة'),
              onPressed: _showSuspendedSalesDialog,
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.playlist_add),
              label: const Text('إضافة دواء يدويًا'),
              onPressed: () => showManualAddToCartDialog(
                context,
                onAdd: (medicine, qty, unitName, multiplier, unitPrice) {
                  ref.read(posNotifierProvider.notifier).addMedicineWithQuantity(medicine, qty, unitName, multiplier, unitPrice);
                  _barcodeFocusNode.requestFocus();
                },
              ),
            ),
            const SizedBox(width: 12),
            // إحصائيات نقطة البيع والدرج المباشرة
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'مبيعات اليوم: ${state.todaySalesTotal.toStringAsFixed(0)} ر.ي',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'مرتجعات اليوم: ${state.todayReturnsTotal.toStringAsFixed(0)} ر.ي',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'نقد درج الصيدلية: ${state.cashInDrawerTotal.toStringAsFixed(0)} ر.ي',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'تحديث بيانات الدرج والمبيعات',
              onPressed: () => ref.read(posNotifierProvider.notifier).refreshStats(),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // القسم الأيمن: سلة المشتريات ومسح الباركود
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _barcodeController,
                            focusNode: _barcodeFocusNode,
                            autofocus: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                              hintText: 'امسح الباركود أو أدخله يدويًا ثم اضغط Enter...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            onSubmitted: _submitBarcode,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.clear_all),
                          tooltip: 'إفراغ السلة',
                          onPressed: state.items.isNotEmpty
                              ? () => ref.read(posNotifierProvider.notifier).clearCart()
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (state.errorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (state.items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ClinicalInteractionBanner(
                        cartMedicines: state.cartMedicines,
                      ),
                    ),
                  Expanded(
                    child: state.items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'السلة فارغة - امسح الباركود أو ابحث عن دواء للبدء',
                                  style: TextStyle(fontSize: 15, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Scrollbar(
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 1050,
                                  child: Column(
                                    children: [
                                      _buildCartTableHeader(),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: state.items.length,
                                          itemBuilder: (context, index) {
                                            final item = state.items[index];
                                            return CartItemRow(
                                              item: item,
                                              index: index,
                                              onQuantityChanged: (q) => ref
                                                  .read(posNotifierProvider.notifier)
                                                  .updateQuantity(item.medicineId, item.selectedUnitMultiplier, q),
                                              onPriceChanged: (p) => ref
                                                  .read(posNotifierProvider.notifier)
                                                  .updateItemPrice(item.medicineId, item.selectedUnitMultiplier, p),
                                              onBatchChanged: (batchId, expiryDate) => ref
                                                  .read(posNotifierProvider.notifier)
                                                  .updateCartItemBatch(item.medicineId, item.selectedUnitMultiplier, batchId, expiryDate),
                                              onRemove: () => ref
                                                  .read(posNotifierProvider.notifier)
                                                  .removeItem(item.medicineId, item.selectedUnitMultiplier),
                                              onUnitChangeRequested: () => _showUnitChangeDialog(context, ref, item),
                                              onFindAlternatives: () => _showAlternativesDialog(context, item),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // القسم الأيسر: لوحة الحساب وطرق الدفع والإنهاء
            SizedBox(
              width: 380,
              height: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(-2, 0)),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('ملخص الفاتورة والدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Divider(height: 20),

                      // الإجمالي الفرعي
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي الفرعي:', style: TextStyle(fontSize: 14)),
                          Text(
                            '${state.subtotal.toStringAsFixed(0)} ر.ي',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // الخصم
                      Row(
                        children: [
                          const Text('الخصم:', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _discountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                errorText: _discountError,
                                isDense: true,
                                suffixText: 'ر.ي',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      
                      if (state.taxEnabled) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الضريبة المضافة (${state.taxRate}%):', style: const TextStyle(fontSize: 14)),
                            Text(
                              '${state.taxAmount.toStringAsFixed(0)} ر.ي',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                      ],

                      // الإجمالي النهائي
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المبلغ المطلوب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            '${state.total.toStringAsFixed(0)} ر.ي',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // الربط الطبي (اختياري)
                      const Text('الربط الطبي (اختياري):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          // Doctor Picker
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final doctors = ref.watch(doctorsProvider).value ?? [];
                                return InkWell(
                                  onTap: () async {
                                    final selected = await showSearchableEntityPicker<DoctorRow>(
                                      context: context,
                                      items: doctors,
                                      title: 'اختر الطبيب',
                                      searchHint: 'ابحث عن طبيب...',
                                      itemLabelBuilder: (d) => '${d.name} - ${d.specialty ?? ""}',
                                      searchFilter: (d, query) => d.name.toLowerCase().contains(query.toLowerCase()),
                                    );
                                    if (selected != null) {
                                      ref.read(posNotifierProvider.notifier).copyWithState(
                                        selectedDoctorId: selected.id,
                                        selectedDoctorName: selected.name,
                                      );
                                    } else {
                                      ref.read(posNotifierProvider.notifier).copyWithState(clearMedical: true); // Allow clearing
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(labelText: 'الطبيب', border: OutlineInputBorder(), isDense: true),
                                    child: Text(state.selectedDoctorName ?? 'بدون طبيب', overflow: TextOverflow.ellipsis),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Prescription Picker
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final prescriptions = ref.watch(prescriptionsProvider).value ?? [];
                                return InkWell(
                                  onTap: () async {
                                    final selected = await showSearchableEntityPicker<PrescriptionRow>(
                                      context: context,
                                      items: prescriptions,
                                      title: 'اختر الوصفة الطبية',
                                      searchHint: 'ابحث عن وصفة...',
                                      itemLabelBuilder: (p) => 'وصفة ${p.prescriptionNumber ?? p.id} - ${p.diagnosis ?? ""}',
                                      searchFilter: (p, query) => (p.prescriptionNumber ?? "").toLowerCase().contains(query.toLowerCase()) || (p.diagnosis ?? "").toLowerCase().contains(query.toLowerCase()),
                                    );
                                    if (selected != null) {
                                      ref.read(posNotifierProvider.notifier).copyWithState(
                                        selectedPrescriptionId: selected.id,
                                        selectedPrescriptionNumber: selected.prescriptionNumber,
                                      );
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(labelText: 'الوصفة', border: OutlineInputBorder(), isDense: true),
                                    child: Text(state.selectedPrescriptionNumber != null ? 'وصفة ${state.selectedPrescriptionNumber}' : (state.selectedPrescriptionId != null ? 'وصفة ${state.selectedPrescriptionId}' : 'بدون وصفة'), overflow: TextOverflow.ellipsis),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // اختيار طريقة الدفع
                      const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            avatar: const Icon(Icons.payments_outlined, size: 16),
                            label: const Text('نقدي'),
                            selected: state.paymentMethod == 'نقدي',
                            onSelected: (_) => ref.read(posNotifierProvider.notifier).setPaymentMethod('نقدي'),
                          ),
                          ChoiceChip(
                            avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                            label: const Text('محفظة إلكترونية'),
                            selected: state.paymentMethod == 'محفظة',
                            onSelected: (_) => ref.read(posNotifierProvider.notifier).setPaymentMethod('محفظة'),
                          ),
                          ChoiceChip(
                            avatar: const Icon(Icons.person_outline, size: 16),
                            label: const Text('آجل (دين على عميل)'),
                            selected: state.paymentMethod == 'آجل',
                            onSelected: (_) => ref.read(posNotifierProvider.notifier).setPaymentMethod('آجل'),
                          ),
                        ],
                      ),

                      // خيارات المحفظة الإلكترونية
                      if (state.paymentMethod == 'محفظة') ...[
                        const SizedBox(height: 12),
                        walletsAsync.when(
                          data: (wallets) {
                            if (wallets.isEmpty) {
                              return const Text('لا توجد محافظ معرفة');
                            }
                            return DropdownButtonFormField<int>(
                              decoration: InputDecoration(
                                labelText: 'اختر المحفظة',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              value: _selectedWalletId ?? wallets.first.id,
                              items: wallets
                                  .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                                  .toList(),
                              onChanged: (val) {
                                setState(() => _selectedWalletId = val);
                              },
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text('تعذر تحميل المحافظ'),
                        ),
                      ],

                      // خيارات البيع الآجل والعميل
                      if (state.isCreditSale) ...[
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, _) {
                            final customers = ref.watch(customersNotifierProvider).items;
                            return Row(
                              children: [
                                Expanded(
                                  child: customers.isEmpty
                                      ? const Text('لا يوجد عملاء مضافين بعد')
                                      : DropdownButtonFormField<int>(
                                          value: state.selectedCustomerId,
                                          hint: const Text('اختر العميل المدين'),
                                          decoration: InputDecoration(
                                            labelText: 'العميل المدين',
                                            isDense: true,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          items: customers
                                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                              .toList(),
                                          onChanged: (value) {
                                            if (value == null) return;
                                            final name = customers.firstWhere((c) => c.id == value).name;
                                            ref.read(posNotifierProvider.notifier).setCustomer(value, name);
                                          },
                                        ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.person_add),
                                  tooltip: 'إضافة عميل جديد',
                                  onPressed: _showAddNewCustomerDialog,
                                ),
                              ],
                            );
                          },
                        ),
                      ],

                      // إدخال المبلغ المستلم وحساب الباقي (للنقدي)
                      if (!state.isCreditSale) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountReceivedController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'المبلغ المستلم من العميل',
                            isDense: true,
                            suffixText: 'ر.ي',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (value) => ref
                              .read(posNotifierProvider.notifier)
                              .setAmountReceived(double.tryParse(value) ?? 0),
                        ),
                        if (_amountReceivedController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الباقي للعميل:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                state.changeOwed >= 0
                                    ? '${state.changeOwed.toStringAsFixed(0)} ر.ي'
                                    : 'المبلغ ناقص (${(-state.changeOwed).toStringAsFixed(0)})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: state.changeOwed >= 0 ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],

                      const SizedBox(height: 24),

                      // زر إتمام البيع
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          icon: state.isProcessing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('إتمام عملية البيع وحفظ الفاتورة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: state.isProcessing ? null : _checkout,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: const Row(
        children: [
          SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 250, child: Text('اسم الدواء', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 100, child: Text('الوحدة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 120, child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 130, child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 130, child: Text('الانتهاء', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          SizedBox(width: 120, child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          Expanded(child: Text('الإجراءات', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
        ],
      ),
    );
  }
}
