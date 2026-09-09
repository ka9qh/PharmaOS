// نماذج بيانات تطبيق المدير المحمول - PharmaOS Owner App
class OwnerTenantConfig {
  final int pharmacyId;
  final String pharmacyName;
  final String licenseKey;
  final String managerName;
  final String supabaseUrl;
  final String supabaseKey;

  OwnerTenantConfig({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.licenseKey,
    required this.managerName,
    this.supabaseUrl = 'https://bwgilcmzffcwdcxhfyfk.supabase.co',
    this.supabaseKey = 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16',
  });
}

class CloudSale {
  final int id;
  final int pharmacyId;
  final int? branchId;
  final String invoiceNumber;
  final double totalAmount;
  final double discountAmount;
  final double netAmount;
  final double paidAmount;
  final String paymentMethod;
  final String? cashierName;
  final String? customerName;
  final DateTime createdAt;

  CloudSale({
    required this.id,
    required this.pharmacyId,
    this.branchId,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.discountAmount,
    required this.netAmount,
    required this.paidAmount,
    required this.paymentMethod,
    this.cashierName,
    this.customerName,
    required this.createdAt,
  });

  factory CloudSale.fromJson(Map<String, dynamic> json) {
    return CloudSale(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id'].toString()) ?? 1,
      branchId: json['branch_id'] != null ? int.tryParse(json['branch_id'].toString()) : null,
      invoiceNumber: json['invoice_number'] ?? 'INV-000',
      totalAmount: (json['total_amount'] != null) ? (double.tryParse(json['total_amount'].toString()) ?? 0.0) : 0.0,
      discountAmount: (json['discount_amount'] != null) ? (double.tryParse(json['discount_amount'].toString()) ?? 0.0) : 0.0,
      netAmount: (json['net_amount'] != null) ? (double.tryParse(json['net_amount'].toString()) ?? 0.0) : 0.0,
      paidAmount: (json['paid_amount'] != null) ? (double.tryParse(json['paid_amount'].toString()) ?? 0.0) : 0.0,
      paymentMethod: json['payment_method'] ?? 'نقدي',
      cashierName: json['cashier_name'],
      customerName: json['customer_name'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class CloudDayClosing {
  final int id;
  final int pharmacyId;
  final int? branchId;
  final DateTime date;
  final double totalSales;
  final double totalReturns;
  final double totalExpenses;
  final double netProfit;
  final double cashInDrawer;
  final DateTime createdAt;

  CloudDayClosing({
    required this.id,
    required this.pharmacyId,
    this.branchId,
    required this.date,
    required this.totalSales,
    required this.totalReturns,
    required this.totalExpenses,
    required this.netProfit,
    required this.cashInDrawer,
    required this.createdAt,
  });

  factory CloudDayClosing.fromJson(Map<String, dynamic> json) {
    return CloudDayClosing(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id'].toString()) ?? 1,
      branchId: json['branch_id'] != null ? int.tryParse(json['branch_id'].toString()) : null,
      date: json['date'] != null ? DateTime.tryParse(json['date']) ?? DateTime.now() : DateTime.now(),
      totalSales: (json['total_sales'] != null) ? (double.tryParse(json['total_sales'].toString()) ?? 0.0) : 0.0,
      totalReturns: (json['total_returns'] != null) ? (double.tryParse(json['total_returns'].toString()) ?? 0.0) : 0.0,
      totalExpenses: (json['total_expenses'] != null) ? (double.tryParse(json['total_expenses'].toString()) ?? 0.0) : 0.0,
      netProfit: (json['net_profit'] != null) ? (double.tryParse(json['net_profit'].toString()) ?? 0.0) : 0.0,
      cashInDrawer: (json['cash_in_drawer'] != null) ? (double.tryParse(json['cash_in_drawer'].toString()) ?? 0.0) : 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class CloudMedicine {
  final int id;
  final int pharmacyId;
  final String nameAr;
  final String? nameEn;
  final String? nameScientific;
  final String? barcode;
  final String? sku;
  final double sellingPrice;
  final double purchasePrice;

  CloudMedicine({
    required this.id,
    required this.pharmacyId,
    required this.nameAr,
    this.nameEn,
    this.nameScientific,
    this.barcode,
    this.sku,
    required this.sellingPrice,
    required this.purchasePrice,
  });

  factory CloudMedicine.fromJson(Map<String, dynamic> json) {
    return CloudMedicine(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id'].toString()) ?? 1,
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'],
      nameScientific: json['name_scientific'],
      barcode: json['barcode'],
      sku: json['sku'],
      sellingPrice: (json['selling_price'] != null) ? (double.tryParse(json['selling_price'].toString()) ?? 0.0) : 0.0,
      purchasePrice: (json['purchase_price'] != null) ? (double.tryParse(json['purchase_price'].toString()) ?? 0.0) : 0.0,
    );
  }
}

class OwnerTeleConsultation {
  final int id;
  final int pharmacyId;
  final int? branchId;
  final String pharmacistName;
  final String title;
  final String? patientName;
  final String? notes;
  final String? imageBase64;
  final String? imageUrl;
  final String? voiceBase64;
  final String status;
  final String urgency;
  final String? suggestedMedicines;
  final String? managerReply;
  final String? managerName;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? resolvedAt;

  OwnerTeleConsultation({
    required this.id,
    required this.pharmacyId,
    this.branchId,
    required this.pharmacistName,
    required this.title,
    this.patientName,
    this.notes,
    this.imageBase64,
    this.imageUrl,
    this.voiceBase64,
    required this.status,
    required this.urgency,
    this.suggestedMedicines,
    this.managerReply,
    this.managerName,
    required this.createdAt,
    this.answeredAt,
    this.resolvedAt,
  });

  factory OwnerTeleConsultation.fromJson(Map<String, dynamic> json) {
    return OwnerTeleConsultation(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id'].toString()) ?? 1,
      branchId: json['branch_id'] != null ? int.tryParse(json['branch_id'].toString()) : null,
      pharmacistName: json['pharmacist_name'] ?? 'الصيدلي',
      title: json['title'] ?? 'استشارة طبية',
      patientName: json['patient_name'],
      notes: json['notes'],
      imageBase64: json['image_base64'],
      imageUrl: json['image_url'],
      voiceBase64: json['voice_base64'],
      status: json['status'] ?? 'pending',
      urgency: json['urgency'] ?? 'normal',
      suggestedMedicines: json['suggested_medicines'],
      managerReply: json['manager_reply'],
      managerName: json['manager_name'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
      answeredAt: json['answered_at'] != null ? DateTime.tryParse(json['answered_at']) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at']) : null,
    );
  }
}
