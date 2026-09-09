// إدارة حالة سلة نقطة البيع بالكامل - بحث بالباركود، تعديل الكميات، الخصم،
// وإتمام البيع فعليًا عبر ميزة sales (CreateSaleUseCase).
//
// تحديث: أُضيفت addMedicineWithQuantity - إضافة يدوية بالبحث عن الاسم مع
// اختيار الوحدة (حبة/شريط/باكت) بدل الاعتماد فقط على مسح الباركود (كل مسح
// باركود = +1 وحدة أساسية دائمًا، لا يتغيّر). راجع
// presentation/widgets/manual_add_dialog.dart والزر الجديد في pos_screen.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/pos_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';
import '../../../medicines/domain/usecases/medicines_usecase.dart';
import '../../../inventory/domain/repositories/inventory_repository.dart';
import '../../../inventory/domain/usecases/inventory_usecase.dart';
import '../../../sales/domain/entities/sales_entity.dart';
import '../../../sales/domain/repositories/sales_repository.dart';
import '../../../sales/domain/usecases/sales_usecase.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../returns/domain/repositories/returns_repository.dart';
import '../../../cash_register/domain/repositories/cash_register_repository.dart';

class PosCartState {
  final List<CartItem> items;
  final double discount;
  final String paymentMethod;
  final int? walletId; // Null for 'نقدي' if not specified, but required for 'محفظة'
  final double amountReceived; // المبلغ الذي أعطاه العميل نقدًا - لحساب الباقي (أو كدفعة مقدمة للآجل)
  final int? selectedCustomerId;
  final String? selectedCustomerName;
  
  // Phase 2: Doctor and Prescription
  final int? selectedDoctorId;
  final String? selectedDoctorName;
  final int? selectedPrescriptionId;
  final String? selectedPrescriptionNumber;
  
  final bool isProcessing;
  final String? errorMessage;
  final String? lastCompletedInvoice;
  final double? lastCompletedTotal;
  final double? lastCompletedChange;
  final double todaySalesTotal;
  final double todayReturnsTotal;
  final double cashInDrawerTotal;
  
  // Tax
  final bool taxEnabled;
  final double taxRate;

  // Clinical AI Entities
  final Map<int, MedicineEntity> medicineEntities;

  const PosCartState({
    this.items = const [],
    this.discount = 0,
    this.paymentMethod = 'نقدي',
    this.walletId,
    this.amountReceived = 0,
    this.selectedCustomerId,
    this.selectedCustomerName,
    this.selectedDoctorId,
    this.selectedDoctorName,
    this.selectedPrescriptionId,
    this.selectedPrescriptionNumber,
    this.isProcessing = false,
    this.errorMessage,
    this.lastCompletedInvoice,
    this.lastCompletedTotal,
    this.lastCompletedChange,
    this.todaySalesTotal = 0,
    this.todayReturnsTotal = 0,
    this.cashInDrawerTotal = 0,
    this.taxEnabled = false,
    this.taxRate = 15.0,
    this.medicineEntities = const {},
  });

  List<MedicineEntity> get cartMedicines {
    final list = <MedicineEntity>[];
    for (final item in items) {
      final med = medicineEntities[item.medicineId];
      if (med != null && !list.any((m) => m.id == med.id)) {
        list.add(med);
      }
    }
    return list;
  }

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);
  
  double get effectiveDiscount => discount > subtotal ? subtotal : discount;
  
  double get amountAfterDiscount => subtotal - effectiveDiscount;
  double get taxAmount => taxEnabled ? amountAfterDiscount * (taxRate / 100) : 0.0;
  
  double get total => amountAfterDiscount + taxAmount;
  
  bool get isCreditSale => paymentMethod == 'آجل';

  /// الباقي المستحق للعميل = المبلغ المستلم - الإجمالي. سالب يعني المبلغ
  /// المستلم غير كافٍ بعد (لا نعرضه كباقي سلبي بالواجهة - نمنع إتمام البيع).
  double get changeOwed => amountReceived - total;

  PosCartState copyWith({
    List<CartItem>? items,
    double? discount,
    String? paymentMethod,
    int? walletId,
    double? amountReceived,
    int? selectedCustomerId,
    String? selectedCustomerName,
    int? selectedDoctorId,
    String? selectedDoctorName,
    int? selectedPrescriptionId,
    String? selectedPrescriptionNumber,
    bool? isProcessing,
    String? errorMessage,
    String? lastCompletedInvoice,
    double? lastCompletedTotal,
    double? lastCompletedChange,
    double? todaySalesTotal,
    double? todayReturnsTotal,
    double? cashInDrawerTotal,
    bool? taxEnabled,
    double? taxRate,
    Map<int, MedicineEntity>? medicineEntities,
    bool clearError = false,
    bool clearLastCompleted = false,
    bool clearCustomer = false,
    bool clearMedical = false,
  }) {
    return PosCartState(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      // walletId: walletId ?? this.walletId,
      amountReceived: amountReceived ?? this.amountReceived,
      selectedCustomerId: clearCustomer ? null : (selectedCustomerId ?? this.selectedCustomerId),
      selectedCustomerName: clearCustomer ? null : (selectedCustomerName ?? this.selectedCustomerName),
      selectedDoctorId: clearMedical ? null : (selectedDoctorId ?? this.selectedDoctorId),
      selectedDoctorName: clearMedical ? null : (selectedDoctorName ?? this.selectedDoctorName),
      selectedPrescriptionId: clearMedical ? null : (selectedPrescriptionId ?? this.selectedPrescriptionId),
      selectedPrescriptionNumber: clearMedical ? null : (selectedPrescriptionNumber ?? this.selectedPrescriptionNumber),
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastCompletedInvoice:
          clearLastCompleted ? null : (lastCompletedInvoice ?? this.lastCompletedInvoice),
      lastCompletedTotal:
          clearLastCompleted ? null : (lastCompletedTotal ?? this.lastCompletedTotal),
      lastCompletedChange:
          clearLastCompleted ? null : (lastCompletedChange ?? this.lastCompletedChange),
      todaySalesTotal: todaySalesTotal ?? this.todaySalesTotal,
      todayReturnsTotal: todayReturnsTotal ?? this.todayReturnsTotal,
      cashInDrawerTotal: cashInDrawerTotal ?? this.cashInDrawerTotal,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxRate: taxRate ?? this.taxRate,
      medicineEntities: medicineEntities ?? this.medicineEntities,
    );
  }
}

class PosNotifier extends Notifier<PosCartState> {
  @override
  PosCartState build() {
    Future.microtask(() async {
      await _loadTodayStats();
      await _loadTaxSettings();
    });
    return const PosCartState();
  }

  void copyWithState({
    int? selectedDoctorId,
    String? selectedDoctorName,
    int? selectedPrescriptionId,
    String? selectedPrescriptionNumber,
    bool clearMedical = false,
  }) {
    state = state.copyWith(
      selectedDoctorId: selectedDoctorId,
      selectedDoctorName: selectedDoctorName,
      selectedPrescriptionId: selectedPrescriptionId,
      selectedPrescriptionNumber: selectedPrescriptionNumber,
      clearMedical: clearMedical,
    );
  }

  Future<void> _loadTaxSettings() async {
    try {
      final settings = await sl<SettingsRepository>().load();
      state = state.copyWith(taxEnabled: settings.taxEnabled, taxRate: settings.taxRate);
    } catch (_) {}
  }

  Future<void> _loadTodayStats() async {
    try {
      final totalSales = await GetTodaySalesTotalUseCase(sl<SalesRepository>()).call();
      final totalReturns = await sl<ReturnsRepository>().getTodayReturnsTotal();
      final cashInDrawer = await sl<CashRegisterRepository>().getCashBalance();
      state = state.copyWith(
        todaySalesTotal: totalSales,
        todayReturnsTotal: totalReturns,
        cashInDrawerTotal: cashInDrawer,
      );
    } catch (_) {
      // فشل تحميل مؤشر مبيعات اليوم لا يجب أن يوقف عمل نقطة البيع نفسها
    }
  }

  Future<void> refreshStats() async {
    await _loadTodayStats();
  }

  Future<void> _addToCart(MedicineEntity medicine, int selectedQuantity, String unitName, int unitMultiplier, [double? explicitUnitPrice]) async {
    if (selectedQuantity <= 0) return;

    final quantityInBase = selectedQuantity * unitMultiplier;
    final available = await GetAvailableQuantityUseCase(sl<InventoryRepository>()).call(medicine.id);
    
    // Check if the exact same unit is already in the cart for this medicine
    final existingIndex = state.items.indexWhere((i) => i.medicineId == medicine.id && i.selectedUnitMultiplier == unitMultiplier);

    final updatedEntities = Map<int, MedicineEntity>.from(state.medicineEntities);
    updatedEntities[medicine.id] = medicine;

    if (existingIndex != -1) {
      final existing = state.items[existingIndex];
      final newSelectedQty = existing.selectedQuantity + selectedQuantity;
      final newQtyInBase = newSelectedQty * unitMultiplier;
      
      // We must check the total base quantity for this medicine across ALL cart items
      // (in case they added 1 pack and 1 strip of the same medicine)
      final currentTotalInOtherRows = state.items
          .where((i) => i.medicineId == medicine.id && i.selectedUnitMultiplier != unitMultiplier)
          .fold(0, (sum, i) => sum + i.quantityInBase);
          
      if ((newQtyInBase + currentTotalInOtherRows) > available) {
        state = state.copyWith(
            errorMessage: 'الكمية المتوفرة من "${medicine.nameAr}" غير كافية (المتاح: $available حبة/أساسي)');
        return;
      }
      
      final updated = [...state.items];
      updated[existingIndex] = existing.copyWith(selectedQuantity: newSelectedQty);
      state = state.copyWith(items: updated, medicineEntities: updatedEntities, clearError: true);
    } else {
      final currentTotalInOtherRows = state.items
          .where((i) => i.medicineId == medicine.id)
          .fold(0, (sum, i) => sum + i.quantityInBase);
          
      if ((quantityInBase + currentTotalInOtherRows) > available) {
        state = state.copyWith(
            errorMessage: available <= 0
                ? 'لا يوجد مخزون متوفر من "${medicine.nameAr}"'
                : 'الكمية المتوفرة من "${medicine.nameAr}" غير كافية (المتاح: $available حبة/أساسي)');
        return;
      }
      
      state = state.copyWith(items: [
        ...state.items,
        CartItem(
          medicineId: medicine.id,
          medicineName: medicine.nameAr,
          unitPrice: explicitUnitPrice ?? medicine.sellingPrice,
          availableStockInBase: available,
          selectedUnitName: unitName,
          selectedUnitMultiplier: unitMultiplier,
          selectedQuantity: selectedQuantity,
        ),
      ], medicineEntities: updatedEntities, clearError: true);
    }
  }

  void scanBarcodeNotFound(String barcode) {
    state = state.copyWith(errorMessage: 'لا يوجد دواء بهذا الباركود: $barcode');
  }

  Future<void> loadInvoiceForEditing(InvoiceEntity invoice) async {
    final inventoryRepo = sl<InventoryRepository>();
    final newItems = <CartItem>[];
    for (final item in invoice.items) {
      final available = await GetAvailableQuantityUseCase(inventoryRepo).call(item.medicineId);
      newItems.add(CartItem(
        medicineId: item.medicineId,
        medicineName: item.medicineName,
        unitPrice: item.unitPrice,
        availableStockInBase: available, // We don't restore the stock until the return is processed
        selectedUnitName: item.unitName,
        selectedUnitMultiplier: item.conversionFactor,
        selectedQuantity: item.selectedQuantity,
      ));
    }
    state = PosCartState(
      items: newItems,
      discount: invoice.discount,
      paymentMethod: invoice.paymentMethod,
      todaySalesTotal: state.todaySalesTotal,
      taxEnabled: state.taxEnabled,
      taxRate: state.taxRate,
    );
  }

  Future<void> addMedicineWithQuantity(MedicineEntity medicine, int selectedQuantity, String unitName, int unitMultiplier, double unitPrice) async {
    state = state.copyWith(clearError: true);
    try {
      await _addToCart(medicine, selectedQuantity, unitName, unitMultiplier, unitPrice);
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إضافة "${medicine.nameAr}" للسلة');
    }
  }

  void updateQuantity(int medicineId, int unitMultiplier, int newSelectedQuantity) {
    final index = state.items.indexWhere((i) => i.medicineId == medicineId && i.selectedUnitMultiplier == unitMultiplier);
    if (index == -1) return;
    final item = state.items[index];

    if (newSelectedQuantity <= 0) {
      removeItem(medicineId, unitMultiplier);
      return;
    }
    
    final newQtyInBase = newSelectedQuantity * unitMultiplier;
    final currentTotalInOtherRows = state.items
        .where((i) => i.medicineId == medicineId && i.selectedUnitMultiplier != unitMultiplier)
        .fold(0, (sum, i) => sum + i.quantityInBase);
        
    if ((newQtyInBase + currentTotalInOtherRows) > item.availableStockInBase) {
      state = state.copyWith(
          errorMessage: 'الحد الأقصى المتوفر من "${item.medicineName}" هو ${item.availableStockInBase} (أساسي)');
      return;
    }
    
    final updated = [...state.items];
    updated[index] = item.copyWith(selectedQuantity: newSelectedQuantity);
    state = state.copyWith(items: updated, clearError: true);
  }

  void updateCartItemBatch(int medicineId, int unitMultiplier, int? batchId, DateTime? expiryDate) {
    final index = state.items.indexWhere((i) => i.medicineId == medicineId && i.selectedUnitMultiplier == unitMultiplier);
    if (index == -1) return;
    
    final item = state.items[index];
    final updated = [...state.items];
    updated[index] = item.copyWith(batchId: batchId, expiryDate: expiryDate);
    state = state.copyWith(items: updated, clearError: true);
  }

  void updateItemPrice(int medicineId, int unitMultiplier, double newUnitPrice) {
    final index = state.items.indexWhere((i) => i.medicineId == medicineId && i.selectedUnitMultiplier == unitMultiplier);
    if (index == -1 || newUnitPrice < 0) return;
    final item = state.items[index];
    final updated = [...state.items];
    updated[index] = item.copyWith(unitPrice: newUnitPrice);
    state = state.copyWith(items: updated, clearError: true);
  }

  void changeItemUnit(int medicineId, int oldUnitMultiplier, String newUnitName, int newUnitMultiplier, double newUnitPrice) {
    final index = state.items.indexWhere((i) => i.medicineId == medicineId && i.selectedUnitMultiplier == oldUnitMultiplier);
    if (index == -1) return;
    
    // Check if the new unit already exists in another row
    final existingNewUnitIndex = state.items.indexWhere((i) => i.medicineId == medicineId && i.selectedUnitMultiplier == newUnitMultiplier && i != state.items[index]);
    
    if (existingNewUnitIndex != -1) {
      // Merge with existing row
      final itemToMerge = state.items[index];
      final targetRow = state.items[existingNewUnitIndex];
      
      final updated = [...state.items];
      updated[existingNewUnitIndex] = targetRow.copyWith(
        selectedQuantity: targetRow.selectedQuantity + itemToMerge.selectedQuantity,
      );
      updated.removeAt(index);
      state = state.copyWith(items: updated, clearError: true);
    } else {
      // Just change the unit of the current row
      final item = state.items[index];
      final updated = [...state.items];
      updated[index] = item.copyWith(
        selectedUnitName: newUnitName,
        selectedUnitMultiplier: newUnitMultiplier,
        unitPrice: newUnitPrice,
      );
      state = state.copyWith(items: updated, clearError: true);
    }
  }



  void removeItem(int medicineId, int unitMultiplier) {
    state = state.copyWith(
      items: state.items.where((i) => !(i.medicineId == medicineId && i.selectedUnitMultiplier == unitMultiplier)).toList(),
      clearError: true,
    );
  }

  void setDiscount(double value) {
    if (value < 0) value = 0;
    state = state.copyWith(discount: value, clearError: true);
  }

  void setPaymentMethod(String method, {int? walletId}) {
    state = state.copyWith(
      paymentMethod: method,
      // walletId: walletId,
      clearError: true,
      // عند الرجوع لـ "نقدي" أو "محفظة" لا حاجة للعميل المختار سابقًا (إلا إذا أردنا تسجيل عميل)
      clearCustomer: method != 'آجل',
    );
  }

  /// المبلغ الذي أعطاه العميل نقدًا - يُستخدم لحساب الباقي المستحق له قبل
  /// إتمام البيع (وليس فقط بعده)، ليعرف الكاشير كم يرجع للعميل فورًا.
  void setAmountReceived(double value) {
    state = state.copyWith(amountReceived: value, clearError: true);
  }

  void setCustomer(int customerId, String customerName) {
    state = state.copyWith(
      selectedCustomerId: customerId,
      selectedCustomerName: customerName,
      clearError: true,
    );
  }

  void clearCart() {
    state = PosCartState(
      todaySalesTotal: state.todaySalesTotal,
      taxEnabled: state.taxEnabled,
      taxRate: state.taxRate,
    );
  }

  Future<bool> checkout() async {
    if (state.items.isEmpty) {
      state = state.copyWith(errorMessage: 'السلة فارغة');
      return false;
    }
    if (state.isCreditSale && state.selectedCustomerId == null) {
      state = state.copyWith(errorMessage: 'اختر عميلاً لإتمام البيع الآجل');
      return false;
    }
    // للبيع النقدي فقط: تأكد أن المبلغ المستلم كافٍ قبل إتمام البيع (لا معنى
    // لباقٍ سالب). البيع الآجل لا يحتاج مبلغًا مستلمًا الآن أصلاً.
    if (!state.isCreditSale && state.amountReceived < state.total) {
      state = state.copyWith(
          errorMessage: 'المبلغ المستلم (${state.amountReceived.toStringAsFixed(0)}) '
              'أقل من الإجمالي (${state.total.toStringAsFixed(0)})');
      return false;
    }

    final changeToReturn = state.isCreditSale ? 0.0 : state.changeOwed;

    state = state.copyWith(isProcessing: true, clearError: true, clearLastCompleted: true);

    try {
      final cashierId = ref.read(authNotifierProvider).user?.id;
      final cartInputs = state.items
          .map((i) => CartLineInput(
                medicineId: i.medicineId,
                medicineName: i.medicineName, // Keep original name, unit details are separate
                quantity: i.quantityInBase,
                unitPrice: i.unitPrice,
                unitName: i.selectedUnitName,
                conversionFactor: i.selectedUnitMultiplier,
                selectedQuantity: i.selectedQuantity,
                expiryDate: i.expiryDate,
                batchId: i.batchId,
              ))
          .toList();

      final sale = await CreateSaleUseCase(sl<SalesRepository>()).call(
        items: cartInputs,
        discount: state.effectiveDiscount,
        paymentMethod: state.paymentMethod,
        // walletId: state.walletId,
        cashierId: cashierId,
        customerId: state.isCreditSale ? state.selectedCustomerId : state.selectedCustomerId, // Phase 2: Allow attaching customer to cash sale too if selected
        doctorId: state.selectedDoctorId,
        prescriptionId: state.selectedPrescriptionId,
        // // initialPayment:
      );

      final lastInv = sale.invoiceNumber;
      final lastTot = sale.totalAmount;

      state = PosCartState(
        lastCompletedInvoice: lastInv,
        lastCompletedTotal: lastTot,
        lastCompletedChange: changeToReturn,
        todaySalesTotal: state.todaySalesTotal + sale.totalAmount,
        todayReturnsTotal: state.todayReturnsTotal,
        cashInDrawerTotal: state.cashInDrawerTotal + (state.isCreditSale ? 0.0 : (state.total)),
      );

      // تحميل الأرقام الحقيقية المحدثة من قاعدة البيانات
      _loadTodayStats();
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> suspendCurrentSale(String? referenceNote) async {
    if (state.items.isEmpty) return false;
    state = state.copyWith(isProcessing: true, clearError: true);
    try {
      final cashierId = ref.read(authNotifierProvider).user?.id;
      final cartInputs = state.items
          .map((i) => CartLineInput(
                medicineId: i.medicineId,
                medicineName: i.medicineName,
                quantity: i.quantityInBase,
                unitPrice: i.unitPrice,
                unitName: i.selectedUnitName,
                conversionFactor: i.selectedUnitMultiplier,
                selectedQuantity: i.selectedQuantity,
                expiryDate: i.expiryDate,
                batchId: i.batchId,
              ))
          .toList();

      await sl<SalesRepository>().suspendSale(
        items: cartInputs,
        cashierId: cashierId,
        customerId: state.selectedCustomerId,
        referenceNote: referenceNote,
      );

      clearCart();
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: 'تعذر تعليق الفاتورة');
      return false;
    }
  }

  Future<void> loadSuspendedSale(Map<String, dynamic> heldInvoice) async {
    try {
      final inventoryRepo = sl<InventoryRepository>();
      final cartDataStr = heldInvoice['cartData'] as String;
      if (cartDataStr.isEmpty) return;

      final items = cartDataStr.split('|');
      final newItems = <CartItem>[];
      
      for (final itemStr in items) {
        final parts = itemStr.split(':');
        if (parts.length >= 7) {
          final medId = int.parse(parts[0]);
          final medName = parts[1];
          final unitPrice = double.parse(parts[3]);
          final unitName = parts[4];
          final convFactor = int.parse(parts[5]);
          final selectedQty = int.parse(parts[6]);

          final available = await GetAvailableQuantityUseCase(inventoryRepo).call(medId);
          newItems.add(CartItem(
            medicineId: medId,
            medicineName: medName,
            unitPrice: unitPrice,
            availableStockInBase: available,
            selectedUnitName: unitName,
            selectedUnitMultiplier: convFactor,
            selectedQuantity: selectedQty,
          ));
        }
      }

      state = PosCartState(
        items: newItems,
        todaySalesTotal: state.todaySalesTotal,
        selectedCustomerId: heldInvoice['customerId'], // Although we didn't save customerId in JSON, we can get it from the DB row if we added it to the map. But for now we didn't return customerId in getSuspendedSales. Let's ignore customer selection on resume for now, or the cashier can re-select.
      );

      // delete from db
      await sl<SalesRepository>().deleteSuspendedSale(heldInvoice['id'] as int);

    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر استرجاع الفاتورة المعلقة');
    }
  }
}

final posNotifierProvider = NotifierProvider<PosNotifier, PosCartState>(PosNotifier.new);
