class InvoiceReturnRefEntity {
  final int returnId;
  final String returnNumber;
  final DateTime returnDate;
  final double totalAmount;
  final String settlementMethod; // 'refund', 'debt', 'wallet', 'replacement'
  final String? reason;
  final String returnType; // 'CUSTOMER_RETURN' or 'VENDOR_RETURN'
  final List<InvoiceItemEntity> items;

  const InvoiceReturnRefEntity({
    required this.returnId,
    required this.returnNumber,
    required this.returnDate,
    required this.totalAmount,
    required this.settlementMethod,
    this.reason,
    required this.returnType,
    this.items = const [],
  });
}

class InvoiceEntity {
  final int id; // saleId, purchaseId, or returnId
  final String invoiceNumber; // auto-generated e.g., INV-202610... or PUR-... or RET-...
  final String? invoiceName; // Custom title or description
  final DateTime date;
  final double totalAmount;
  final double discount;
  final String paymentMethod;
  final String type; // 'SALE', 'PURCHASE', 'CUSTOMER_RETURN', 'VENDOR_RETURN'
  final String partyName; // Customer name or Supplier name
  final double? paidAmount; // For credit sales or purchases
  final String? status; // 'completed', 'partially_returned', 'returned'
  final String? originalInvoiceRef; // For returns: reference to original invoice
  final String? reason; // For returns: reason
  final List<InvoiceItemEntity> items;

  // الربط التبادلي بين الفواتير الأصلية وفواتير المرتجعات
  final List<InvoiceReturnRefEntity> linkedReturns;
  final int? originalInvoiceId;
  final String? originalInvoiceNumber;
  final String? originalInvoiceType;

  // Additional fields for expense vouchers
  final String? category;
  final String? workerName;
  final String? recorderName;
  final String? walletName;
  final String? beneficiaryName;

  double get remainingAmount => (paidAmount != null) ? (totalAmount - paidAmount!) : 0;

  bool get isSale => type == 'SALE';
  bool get isPurchase => type == 'PURCHASE';
  bool get isCustomerReturn => type == 'CUSTOMER_RETURN';
  bool get isVendorReturn => type == 'VENDOR_RETURN';
  bool get isReturn => isCustomerReturn || isVendorReturn;
  bool get isExpense => type == 'EXPENSE';

  const InvoiceEntity({
    required this.id,
    required this.invoiceNumber,
    this.invoiceName,
    required this.date,
    required this.totalAmount,
    required this.discount,
    required this.paymentMethod,
    required this.type,
    required this.partyName,
    this.paidAmount,
    this.status,
    this.originalInvoiceRef,
    this.reason,
    required this.items,
    this.linkedReturns = const [],
    this.originalInvoiceId,
    this.originalInvoiceNumber,
    this.originalInvoiceType,
    this.category,
    this.workerName,
    this.recorderName,
    this.walletName,
    this.beneficiaryName,
  });

  InvoiceEntity copyWith({
    int? id,
    String? invoiceNumber,
    String? invoiceName,
    DateTime? date,
    double? totalAmount,
    double? discount,
    String? paymentMethod,
    String? type,
    String? partyName,
    double? paidAmount,
    String? status,
    String? originalInvoiceRef,
    String? reason,
    List<InvoiceItemEntity>? items,
    List<InvoiceReturnRefEntity>? linkedReturns,
    int? originalInvoiceId,
    String? originalInvoiceNumber,
    String? originalInvoiceType,
    String? category,
    String? workerName,
    String? recorderName,
    String? walletName,
    String? beneficiaryName,
  }) {
    return InvoiceEntity(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceName: invoiceName ?? this.invoiceName,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      type: type ?? this.type,
      partyName: partyName ?? this.partyName,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      originalInvoiceRef: originalInvoiceRef ?? this.originalInvoiceRef,
      reason: reason ?? this.reason,
      items: items ?? this.items,
      linkedReturns: linkedReturns ?? this.linkedReturns,
      originalInvoiceId: originalInvoiceId ?? this.originalInvoiceId,
      originalInvoiceNumber: originalInvoiceNumber ?? this.originalInvoiceNumber,
      originalInvoiceType: originalInvoiceType ?? this.originalInvoiceType,
      category: category ?? this.category,
      workerName: workerName ?? this.workerName,
      recorderName: recorderName ?? this.recorderName,
      walletName: walletName ?? this.walletName,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
    );
  }
}

class InvoiceItemEntity {
  final int id; // saleItemId or purchaseItemId
  final int medicineId;
  final String medicineName;
  final int quantity; // In base units (e.g. pills)
  final double unitPrice; // purchase cost or selling price per base unit
  final double subtotal;

  // Additional data for units
  final String unitName;
  final int conversionFactor;
  final int selectedQuantity;

  // Breakdown by unit
  final int qtyCarton;
  final int qtyPack;
  final int qtyStrip;
  final int qtyPill;
  final String? formattedQuantity; // e.g. "1 باكت و 2 شريط و 5 حبات"
  final int medicineType;

  // Packaging hierarchy
  final int qtyPerCarton;
  final int qtyPerPack;
  final int qtyPerStrip;
  final double purchasePrice;
  final double sellingPrice;

  // Additional data for purchases and batches
  final String? batchNumber;
  final DateTime? expiryDate;
  final String? companyName;
  final String? supplierName;

  // أسعار الوحدات المسجلة للصنف
  final double? storedStripPurchasePrice;
  final double? storedStripSellingPrice;
  final double? storedPackPurchasePrice;
  final double? storedPackSellingPrice;
  final double? storedCartonPurchasePrice;
  final double? storedCartonSellingPrice;

  const InvoiceItemEntity({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.unitName,
    required this.conversionFactor,
    required this.selectedQuantity,
    this.qtyCarton = 0,
    this.qtyPack = 0,
    this.qtyStrip = 0,
    this.qtyPill = 0,
    this.formattedQuantity,
    this.medicineType = 1,
    this.qtyPerCarton = 1,
    this.qtyPerPack = 1,
    this.qtyPerStrip = 1,
    this.purchasePrice = 0.0,
    this.sellingPrice = 0.0,
    this.batchNumber,
    this.expiryDate,
    this.companyName,
    this.supplierName,
    double? stripPurchasePrice,
    double? stripSellingPrice,
    double? packPurchasePrice,
    double? packSellingPrice,
    double? cartonPurchasePrice,
    double? cartonSellingPrice,
  })  : storedStripPurchasePrice = stripPurchasePrice,
        storedStripSellingPrice = stripSellingPrice,
        storedPackPurchasePrice = packPurchasePrice,
        storedPackSellingPrice = packSellingPrice,
        storedCartonPurchasePrice = cartonPurchasePrice,
        storedCartonSellingPrice = cartonSellingPrice;

  int get calculatedPillsPerStrip => (qtyPerStrip > 0) ? qtyPerStrip : 1;
  int get calculatedPillsPerPack {
    if (medicineType == 2) {
      // إبر وحقن
      return (qtyPerPack > 0) ? qtyPerPack : 1;
    } else if (medicineType == 3 || medicineType == 4) {
      // علب ومعلبات ومستلزمات
      return 1;
    } else {
      // حبوب وأقراص
      final strip = (qtyPerStrip > 0) ? qtyPerStrip : 1;
      final pack = (qtyPerPack > 0) ? qtyPerPack : 1;
      return pack * strip;
    }
  }
  int get calculatedPillsPerCarton {
    final carton = (qtyPerCarton > 0) ? qtyPerCarton : 1;
    return carton * calculatedPillsPerPack;
  }

  // أسعار التكلفة والشراء
  double get packPurchaseCost {
    if (storedPackPurchasePrice != null && storedPackPurchasePrice! > 0) {
      return storedPackPurchasePrice!;
    }
    if (storedStripPurchasePrice != null && storedStripPurchasePrice! > 0) {
      return storedStripPurchasePrice! * (qtyPerPack > 0 ? qtyPerPack : 1);
    }
    if (purchasePrice > 0) {
      return purchasePrice;
    }
    final perPill = (quantity > 0) ? (subtotal / quantity) : unitPrice;
    return perPill * calculatedPillsPerPack;
  }

  double get stripPurchaseCost {
    if (storedStripPurchasePrice != null && storedStripPurchasePrice! > 0) {
      return storedStripPurchasePrice!;
    }
    if (medicineType == 1 && qtyPerPack > 0) {
      return packPurchaseCost / qtyPerPack;
    }
    return pillPurchaseCost * calculatedPillsPerStrip;
  }

  double get pillPurchaseCost {
    if (calculatedPillsPerPack > 1) {
      return packPurchaseCost / calculatedPillsPerPack;
    }
    if (calculatedPillsPerStrip > 1 && storedStripPurchasePrice != null && storedStripPurchasePrice! > 0) {
      return storedStripPurchasePrice! / calculatedPillsPerStrip;
    }
    if (quantity > 0 && subtotal > 0) {
      return subtotal / quantity;
    }
    return packPurchaseCost;
  }

  double get cartonPurchaseCost {
    if (storedCartonPurchasePrice != null && storedCartonPurchasePrice! > 0) {
      return storedCartonPurchasePrice!;
    }
    final perCartonPacks = (qtyPerCarton > 0) ? qtyPerCarton : 1;
    return packPurchaseCost * perCartonPacks;
  }

  // أسعار البيع
  double get packSellingPrice {
    if (storedPackSellingPrice != null && storedPackSellingPrice! > 0) {
      return storedPackSellingPrice!;
    }
    if (storedStripSellingPrice != null && storedStripSellingPrice! > 0) {
      return storedStripSellingPrice! * (qtyPerPack > 0 ? qtyPerPack : 1);
    }
    if (sellingPrice > 0) {
      return sellingPrice;
    }
    return packPurchaseCost * 1.25;
  }

  double get stripSellingPrice {
    if (storedStripSellingPrice != null && storedStripSellingPrice! > 0) {
      return storedStripSellingPrice!;
    }
    if (medicineType == 1 && qtyPerPack > 0) {
      return packSellingPrice / qtyPerPack;
    }
    return pillSellingPrice * calculatedPillsPerStrip;
  }

  double get pillSellingPrice {
    if (calculatedPillsPerPack > 1) {
      return packSellingPrice / calculatedPillsPerPack;
    }
    if (calculatedPillsPerStrip > 1 && storedStripSellingPrice != null && storedStripSellingPrice! > 0) {
      return storedStripSellingPrice! / calculatedPillsPerStrip;
    }
    return packSellingPrice;
  }

  double get cartonSellingPrice {
    if (storedCartonSellingPrice != null && storedCartonSellingPrice! > 0) {
      return storedCartonSellingPrice!;
    }
    final perCartonPacks = (qtyPerCarton > 0) ? qtyPerCarton : 1;
    return packSellingPrice * perCartonPacks;
  }

  /// العرض النهائي المنسق للكمية والوحدات
  String get displayQuantityWithUnits {
    if (formattedQuantity != null && formattedQuantity!.isNotEmpty) {
      return formattedQuantity!;
    }
    if (unitName.isNotEmpty && selectedQuantity > 0 && selectedQuantity != quantity) {
      return '$selectedQuantity $unitName ($quantity حبة)';
    }
    return '$quantity $unitName';
  }

  /// تحديد سعر الوحدة المباشر المعروض في سطر الفاتورة
  String get displayUnitPriceWithUnit {
    // 1. إذا كان التنسيق المعروض يذكر باكت
    if (displayQuantityWithUnits.contains('باكت')) {
      final match = RegExp(r'(\d+)\s*باكت').firstMatch(displayQuantityWithUnits);
      final packs = match != null ? int.tryParse(match.group(1)!) : null;
      final count = packs ?? (qtyPack > 0 ? qtyPack : (selectedQuantity > 0 ? selectedQuantity : null));
      if (count != null && count > 0) {
        final price = subtotal / count;
        return '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} ر.ي / باكت';
      }
      return '${packPurchaseCost.toStringAsFixed(packPurchaseCost % 1 == 0 ? 0 : 2)} ر.ي / باكت';
    }

    // 2. إذا كان التنسيق المعروض يذكر شريط
    if (displayQuantityWithUnits.contains('شريط')) {
      final match = RegExp(r'(\d+)\s*شريط').firstMatch(displayQuantityWithUnits);
      final strips = match != null ? int.tryParse(match.group(1)!) : null;
      final count = strips ?? (qtyStrip > 0 ? qtyStrip : (selectedQuantity > 0 ? selectedQuantity : null));
      if (count != null && count > 0) {
        final price = subtotal / count;
        return '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} ر.ي / شريط';
      }
      return '${stripPurchaseCost.toStringAsFixed(stripPurchaseCost % 1 == 0 ? 0 : 2)} ر.ي / شريط';
    }

    // 3. إذا كان التنسيق المعروض يذكر كرتون
    if (displayQuantityWithUnits.contains('كرتون')) {
      final match = RegExp(r'(\d+)\s*كرتون').firstMatch(displayQuantityWithUnits);
      final cartons = match != null ? int.tryParse(match.group(1)!) : null;
      final count = cartons ?? (qtyCarton > 0 ? qtyCarton : (selectedQuantity > 0 ? selectedQuantity : null));
      if (count != null && count > 0) {
        final price = subtotal / count;
        return '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} ر.ي / كرتون';
      }
      return '${cartonPurchaseCost.toStringAsFixed(cartonPurchaseCost % 1 == 0 ? 0 : 2)} ر.ي / كرتون';
    }

    // 4. إذا كانت هناك وحدة محددة وكمية محددة
    if (selectedQuantity > 0 && unitName.isNotEmpty && unitName != 'حبة') {
      final linePrice = subtotal / selectedQuantity;
      return '${linePrice.toStringAsFixed(linePrice % 1 == 0 ? 0 : 2)} ر.ي / $unitName';
    }

    // 5. حبات مفردة
    if (quantity > 0) {
      final price = subtotal / quantity;
      return '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} ر.ي / ${unitName.isNotEmpty ? unitName : (medicineType == 1 ? "حبة" : "وحدة")}';
    }

    return '${unitPrice.toStringAsFixed(unitPrice % 1 == 0 ? 0 : 2)} ر.ي';
  }
}
