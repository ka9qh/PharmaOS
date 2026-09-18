// شاشة نقطة البيع (POS) المتقدمة - PharmaOS
// تدعم: قراءة الباركود، البحث اليدوي مع اختيار وحدات البيع (باكت/شريط/حبة)،
// الدفع النقدي، الدفع عبر المحافظ الإلكترونية، الدفع الآجل مع إضافة العميل فورياً،
// والخصومات، وحساب الباقي، وجدول البدائل التفاعلي المباشر، والطباعة الفورية.

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
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../../core/di/service_locator.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../../core/services/clinical_ai_service.dart';
import '../../../ai/presentation/screens/ai_chat_screen.dart';
import '../../../medicines/presentation/screens/wanted_medicines_screen.dart';
import '../../../../core/widgets/floating_ai_assistant.dart';
import '../../../../core/widgets/searchable_entity_picker.dart';
import '../../../../core/database/app_database.dart';
import 'dart:async';
import '../../../doctors/presentation/providers/doctors_provider.dart';
import '../../../prescriptions/presentation/providers/prescriptions_provider.dart';
import '../../../prescriptions/presentation/screens/tele_consultation_dialog.dart';
import '../../../sales/domain/repositories/sales_repository.dart';
import '../../domain/entities/pos_entity.dart';
import '../../../../core/services/shift_manager_service.dart';
import '../../../../core/services/official_date_time_service.dart';
import '../../../closing/presentation/widgets/shift_start_dialog.dart';
import '../../../closing/presentation/widgets/pre_exit_shift_closing_dialog.dart';

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

  int _selectedCartIndex = 0;
  ActiveShiftModel? _activeShift;
  DateTime _currentClock = DateTime.now();
  StreamSubscription? _clockSub;

  @override
  void initState() {
    super.initState();
    _clockSub = OfficialDateTimeService.secondStream.listen((time) {
      if (mounted) setState(() => _currentClock = time);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(posNotifierProvider.notifier).refreshStats();
      await _checkAndPromptShift();
    });
  }

  Future<void> _checkAndPromptShift({bool forceDialog = false}) async {
    final active = await ShiftManagerService.getActiveShift();
    if (active == null || forceDialog) {
      if (!mounted) return;
      final newShift = await ShiftStartDialog.show(context, isDismissible: active != null);
      if (mounted && newShift != null) {
        setState(() {
          _activeShift = newShift;
        });
        ref.read(posNotifierProvider.notifier).refreshStats();
      }
    } else {
      if (mounted) {
        setState(() {
          _activeShift = active;
        });
      }
    }
  }

  @override
  void dispose() {
    _clockSub?.cancel();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _discountController.dispose();
    _amountReceivedController.dispose();
    super.dispose();
  }

  Future<void> _swapMedicineWithAlternative(CartItem targetItem, MedicineEntity newMedicine) async {
    ref.read(posNotifierProvider.notifier).replaceMedicineInCart(targetItem, newMedicine);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تم استبدال "${targetItem.medicineName}" بـ "${newMedicine.nameAr}" فورياً بنجاح 🔄',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
                                  _showSuspendedSalesDialog();
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
      await _swapMedicineWithAlternative(item, selectedAlt);
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
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 118.0, right: 12.0),
          child: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 6,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('المساعد الصيدلاني (AI)', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => FloatingAiDialog.show(context),
          ),
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
            // شارة الوردية / اليومية النشطة
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: _activeShift != null ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.amber.shade100,
                foregroundColor: _activeShift != null ? const Color(0xFF047857) : Colors.amber.shade900,
              ),
              icon: Icon(_activeShift != null ? Icons.verified_user : Icons.warning_amber_rounded, size: 18),
              label: Text(
                _activeShift != null
                    ? 'الوردية #${_activeShift!.id} (${_activeShift!.cashierName})'
                    : 'بدء وردية جديدة',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => _checkAndPromptShift(forceDialog: true),
            ),
            const SizedBox(width: 6),
            // زر إغلاق اليومية المباشر
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF6D28D9),
              ),
              icon: const Icon(Icons.assessment_outlined, size: 18),
              label: const Text('إغلاق اليومية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () async {
                await PreExitShiftClosingDialog.show(
                  context,
                  onProceedToBackupAndExit: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    _checkAndPromptShift(forceDialog: true);
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            // الساعة والوقت المباشر الدقيق بالثواني
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_filled, color: Color(0xFF38BDF8), size: 15),
                    const SizedBox(width: 6),
                    Text(
                      '${OfficialDateTimeService.formatDateArabicWithDay(_currentClock)} | ${OfficialDateTimeService.formatLiveTime(_currentClock)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
        body: Column(
          children: [
            // شريط إدخال الباركود والبحث
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ClinicalInteractionBanner(
                  cartMedicines: state.cartMedicines,
                ),
              ),

            // منطقة سلة المبيعات الشاملة الواسعة (Full-height Cart Table)
            Expanded(
              child: state.items.isEmpty
                  ? _buildEmptyCartState()
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildCartTableHeader(),
                          Expanded(
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 1100,
                                  child: ListView.builder(
                                    itemCount: state.items.length,
                                    itemBuilder: (context, index) {
                                      final item = state.items[index];
                                      return CartItemRow(
                                        item: item,
                                        index: index,
                                        isSelected: index == _selectedCartIndex,
                                        onSelect: () {
                                          setState(() => _selectedCartIndex = index);
                                        },
                                        onQuantityChanged: (q) => ref
                                            .read(posNotifierProvider.notifier)
                                            .updateQuantity(item.medicineId, item.selectedUnitMultiplier, q),
                                        onPriceChanged: (p) => ref
                                            .read(posNotifierProvider.notifier)
                                            .updateItemPrice(item.medicineId, item.selectedUnitMultiplier, p),
                                        onBatchChanged: (batchId, expiryDate) => ref
                                            .read(posNotifierProvider.notifier)
                                            .updateCartItemBatch(item.medicineId, item.selectedUnitMultiplier, batchId, expiryDate),
                                        onRemove: () {
                                          ref
                                              .read(posNotifierProvider.notifier)
                                              .removeItem(item.medicineId, item.selectedUnitMultiplier);
                                        },
                                        onUnitChangeRequested: () => _showUnitChangeDialog(context, ref, item),
                                        onFindAlternatives: () => _showAlternativesDialog(context, item),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // الشريط السفلي العريض لملخص الفاتورة وإتمام البيع
            _buildBottomInvoiceSummaryBar(context, state, walletsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCartState() {
    return Center(
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
    );
  }

  Widget _buildCartTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: const Row(
        children: [
          SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
          SizedBox(width: 250, child: Text('اسم الدواء والتركيب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
          SizedBox(width: 100, child: Text('الوحدة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
          SizedBox(width: 150, child: Text('سعر الوحدة ✏️', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
          SizedBox(width: 150, child: Text('الكمية (+/-)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
          SizedBox(width: 130, child: Text('الانتهاء / الدفعة 📅', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
          SizedBox(width: 120, child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
          Expanded(child: Text('الإجراءات والبدائل', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
        ],
      ),
    );
  }



  Widget _buildBottomInvoiceSummaryBar(BuildContext context, PosCartState state, AsyncValue<List<WalletEntity>> walletsAsync) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط معلومات الوردية والتوقيت المباشر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _activeShift != null ? const Color(0xFF10B981) : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _activeShift != null
                      ? 'الوردية النشطة #${_activeShift!.id} | الكاشير: ${_activeShift!.cashierName} | رصيد الافتتاح: ${_activeShift!.countedOpeningCash.toStringAsFixed(0)} ر.ي'
                      : 'لا توجد وردية نشطة حالياً - يرجى بدء اليومية للبيع المنظم',
                  style: TextStyle(
                    color: _activeShift != null ? const Color(0xFFE2E8F0) : Colors.amber.shade200,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _checkAndPromptShift(forceDialog: true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.settings_outlined, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          _activeShift != null ? 'إدارة الوردية / تقرير اليومية' : 'فتح وردية الآن',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 4),
                      Text(
                        '${OfficialDateTimeService.formatDateArabicWithDay(_currentClock)} - ${OfficialDateTimeService.formatLiveTime(_currentClock)}',
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            // القسم 1: الربط الطبي (Doctor / Prescription)
            SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.medical_services_outlined, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text('الربط الطبي (اختياري):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Consumer(
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
                            ref.read(posNotifierProvider.notifier).copyWithState(clearMedical: true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 14, color: Colors.teal),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  state.selectedDoctorName ?? 'بدون طبيب',
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Consumer(
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
                            searchFilter: (p, query) =>
                                (p.prescriptionNumber ?? "").toLowerCase().contains(query.toLowerCase()) ||
                                (p.diagnosis ?? "").toLowerCase().contains(query.toLowerCase()),
                          );
                          if (selected != null) {
                            ref.read(posNotifierProvider.notifier).copyWithState(
                              selectedPrescriptionId: selected.id,
                              selectedPrescriptionNumber: selected.prescriptionNumber,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long, size: 14, color: Colors.blue),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  state.selectedPrescriptionNumber != null
                                      ? 'وصفة ${state.selectedPrescriptionNumber}'
                                      : (state.selectedPrescriptionId != null ? 'وصفة ${state.selectedPrescriptionId}' : 'بدون وصفة'),
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const VerticalDivider(width: 24, thickness: 1, color: Color(0xFFE2E8F0)),

            // القسم 2: طريقة الدفع والتفاصيل
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Text('طريقة الدفع: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.payments_outlined, size: 14),
                        label: const Text('نقدي', style: TextStyle(fontSize: 11)),
                        selected: state.paymentMethod == 'نقدي',
                        onSelected: (_) => ref.read(posNotifierProvider.notifier).setPaymentMethod('نقدي'),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.account_balance_wallet_outlined, size: 14),
                        label: const Text('محفظة', style: TextStyle(fontSize: 11)),
                        selected: state.paymentMethod == 'محفظة',
                        onSelected: (_) => ref.read(posNotifierProvider.notifier).setPaymentMethod('محفظة'),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.person_outline, size: 14),
                        label: const Text('آجل', style: TextStyle(fontSize: 11)),
                        selected: state.paymentMethod == 'آجل',
                        onSelected: (_) => ref.read(posNotifierProvider.notifier).setPaymentMethod('آجل'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (state.paymentMethod == 'محفظة')
                    walletsAsync.when(
                      data: (wallets) => SizedBox(
                        height: 36,
                        child: DropdownButtonFormField<int>(
                          decoration: InputDecoration(
                            labelText: 'اختر المحفظة',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          value: _selectedWalletId ?? (wallets.isNotEmpty ? wallets.first.id : null),
                          items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) => setState(() => _selectedWalletId = val),
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('تعذر تحميل المحافظ', style: TextStyle(fontSize: 11, color: Colors.red)),
                    )
                  else if (state.isCreditSale)
                    Consumer(
                      builder: (context, ref, _) {
                        final customers = ref.watch(customersNotifierProvider).items;
                        return Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: DropdownButtonFormField<int>(
                                  value: state.selectedCustomerId,
                                  hint: const Text('اختر العميل المدين', style: TextStyle(fontSize: 11)),
                                  decoration: InputDecoration(
                                    labelText: 'العميل المدين',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 12)))).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    final name = customers.firstWhere((c) => c.id == value).name;
                                    ref.read(posNotifierProvider.notifier).setCustomer(value, name);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.person_add, size: 20, color: Colors.blue),
                              tooltip: 'إضافة عميل جديد',
                              onPressed: _showAddNewCustomerDialog,
                            ),
                          ],
                        );
                      },
                    )
                  else
                    Row(
                      children: [
                        SizedBox(
                          width: 140,
                          height: 36,
                          child: TextField(
                            controller: _amountReceivedController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              labelText: 'المستلم من العميل',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              suffixText: 'ر.ي',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onChanged: (value) => ref
                                .read(posNotifierProvider.notifier)
                                .setAmountReceived(double.tryParse(value) ?? 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_amountReceivedController.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: state.changeOwed >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: state.changeOwed >= 0 ? Colors.green.shade200 : Colors.red.shade200),
                            ),
                            child: Text(
                              state.changeOwed >= 0
                                  ? 'الباقي: ${state.changeOwed.toStringAsFixed(0)} ر.ي'
                                  : 'ناقص: ${(-state.changeOwed).toStringAsFixed(0)} ر.ي',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: state.changeOwed >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),

            const VerticalDivider(width: 24, thickness: 1, color: Color(0xFFE2E8F0)),

            // القسم 3: الإجمالي والخصم والضريبة
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Text('الإجمالي الفرعي: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text(
                            '${state.subtotal.toStringAsFixed(0)} ر.ي',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('الخصم: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          SizedBox(
                            width: 80,
                            height: 30,
                            child: TextField(
                              controller: _discountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                errorText: _discountError,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                suffixText: 'ر.ي',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المبلغ المطلوب للبيع:', style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
                          Text(
                            '${state.total.toStringAsFixed(0)} ر.ي',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const VerticalDivider(width: 24, thickness: 1, color: Color(0xFFE2E8F0)),

            // القسم 4: زر الحفظ والإتمام
            SizedBox(
              width: 200,
              child: FilledButton.icon(
                icon: state.isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  'إتمام عملية البيع\nوحفظ الفاتورة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.2),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: state.isProcessing ? null : _checkout,
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),
);
}
}
