// نتائج البحث عن فاتورة (بيع أو شراء) لاختيار السطر المطلوب إرجاعه بالضبط

class SaleItemLookup {
  final int saleItemId;
  final int medicineId;
  final String medicineName;
  final int originalQuantity;
  final int alreadyReturned;
  final double unitPrice;

  const SaleItemLookup({
    required this.saleItemId,
    required this.medicineId,
    required this.medicineName,
    required this.originalQuantity,
    required this.alreadyReturned,
    required this.unitPrice,
  });

  int get maxReturnable => originalQuantity - alreadyReturned;
}

class SaleLookupResult {
  final int saleId;
  final String invoiceNumber;
  final List<SaleItemLookup> items;

  const SaleLookupResult({
    required this.saleId,
    required this.invoiceNumber,
    required this.items,
  });
}

class PurchaseItemLookup {
  final int purchaseItemId;
  final int batchId;
  final int medicineId;
  final String medicineName;
  final int originalQuantity;
  final int alreadyReturned;
  final int currentBatchQuantity;
  final double unitCost;

  const PurchaseItemLookup({
    required this.purchaseItemId,
    required this.batchId,
    required this.medicineId,
    required this.medicineName,
    required this.originalQuantity,
    required this.alreadyReturned,
    required this.currentBatchQuantity,
    required this.unitCost,
  });

  // لا يمكن إرجاع أكثر مما اشتُري أصلًا، ولا أكثر مما هو موجود فعليًا في الدفعة حاليًا
  int get maxReturnable {
    final byOriginal = originalQuantity - alreadyReturned;
    return byOriginal < currentBatchQuantity ? byOriginal : currentBatchQuantity;
  }
}

class PurchaseLookupResult {
  final int purchaseId;
  final String purchaseNumber;
  final List<PurchaseItemLookup> items;

  const PurchaseLookupResult({
    required this.purchaseId,
    required this.purchaseNumber,
    required this.items,
  });
}
