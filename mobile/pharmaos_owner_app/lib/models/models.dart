// نماذج بيانات تطبيق المدير المحمول المحدثة الشاملة - PharmaOS Owner App
import 'dart:convert';

class OwnerTenantConfig {
  final int pharmacyId;
  final String pharmacyName;
  final String licenseKey;
  final String managerName;
  final String supabaseUrl;
  final String supabaseKey;
  final List<String> branches;

  OwnerTenantConfig({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.licenseKey,
    required this.managerName,
    this.supabaseUrl = 'https://bwgilcmzffcwdcxhfyfk.supabase.co',
    this.supabaseKey = 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16',
    this.branches = const ['الفرع الرئيسي'],
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
  final int availableQuantity;
  final int reorderLevel;

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
    this.availableQuantity = 0,
    this.reorderLevel = 5,
  });

  factory CloudMedicine.fromJson(Map<String, dynamic> json) {
    return CloudMedicine(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id']?.toString() ?? '1') ?? 1,
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'],
      nameScientific: json['name_scientific'],
      barcode: json['barcode'],
      sku: json['sku'],
      sellingPrice: (json['selling_price'] != null) ? (double.tryParse(json['selling_price'].toString()) ?? 0.0) : 0.0,
      purchasePrice: (json['purchase_price'] != null) ? (double.tryParse(json['purchase_price'].toString()) ?? 0.0) : 0.0,
      availableQuantity: json['available_quantity'] is int ? json['available_quantity'] : int.tryParse(json['available_quantity']?.toString() ?? '0') ?? 0,
      reorderLevel: json['reorder_level'] is int ? json['reorder_level'] : int.tryParse(json['reorder_level']?.toString() ?? '5') ?? 5,
    );
  }
}

class CloudSupplier {
  final int id;
  final int pharmacyId;
  final String name;
  final String? contactInfo;
  final String? notes;
  final bool isActive;

  CloudSupplier({
    required this.id,
    required this.pharmacyId,
    required this.name,
    this.contactInfo,
    this.notes,
    this.isActive = true,
  });

  factory CloudSupplier.fromJson(Map<String, dynamic> json) {
    return CloudSupplier(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id']?.toString() ?? '1') ?? 1,
      name: json['name'] ?? '',
      contactInfo: json['contact_info'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
    );
  }
}

class CloudBackupRecord {
  final String id;
  final String fileName;
  final int fileSize;
  final DateTime createdAt;
  final String type; // local, cloud, telegram_vault
  final String summaryText;

  CloudBackupRecord({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.createdAt,
    required this.type,
    required this.summaryText,
  });

  factory CloudBackupRecord.fromJson(Map<String, dynamic> json) {
    return CloudBackupRecord(
      id: json['id']?.toString() ?? 'bk-${DateTime.now().millisecondsSinceEpoch}',
      fileName: json['file_name'] ?? 'PharmaOS_Backup.pharmaos_backup',
      fileSize: json['file_size'] is int ? json['file_size'] : int.tryParse(json['file_size']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
      type: json['type'] ?? 'cloud',
      summaryText: json['summary_text'] ?? 'نسخة احتياطية شاملة مشفرة',
    );
  }
}

class StreamFrame {
  final String channel; // screen, camera
  final int pharmacyId;
  final String branchId;
  final String deviceId;
  final String frameBase64;
  final int fps;
  final DateTime timestamp;

  StreamFrame({
    required this.channel,
    required this.pharmacyId,
    required this.branchId,
    required this.deviceId,
    required this.frameBase64,
    this.fps = 15,
    required this.timestamp,
  });

  factory StreamFrame.fromJson(Map<String, dynamic> json) {
    return StreamFrame(
      channel: json['channel'] ?? 'screen',
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id']?.toString() ?? '1') ?? 1,
      branchId: json['branch_id']?.toString() ?? 'main',
      deviceId: json['device_id']?.toString() ?? 'dev-1',
      frameBase64: json['frame_base64'] ?? '',
      fps: json['fps'] is int ? json['fps'] : int.tryParse(json['fps']?.toString() ?? '15') ?? 15,
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class RemotePurchaseItem {
  final int? medicineId;
  final String medicineName;
  final String? barcode;
  final String batchNumber;
  final DateTime expiryDate;
  final int quantity;
  final double purchasePrice;
  final double sellingPrice;
  final double discount;

  RemotePurchaseItem({
    this.medicineId,
    required this.medicineName,
    this.barcode,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.purchasePrice,
    required this.sellingPrice,
    this.discount = 0.0,
  });

  factory RemotePurchaseItem.fromJson(Map<String, dynamic> json) {
    return RemotePurchaseItem(
      medicineId: json['medicine_id'] != null ? int.tryParse(json['medicine_id'].toString()) : null,
      medicineName: json['medicine_name'] ?? '',
      barcode: json['barcode'],
      batchNumber: json['batch_number'] ?? '',
      expiryDate: json['expiry_date'] != null ? DateTime.tryParse(json['expiry_date']) ?? DateTime.now() : DateTime.now(),
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      purchasePrice: (json['purchase_price'] != null) ? (double.tryParse(json['purchase_price'].toString()) ?? 0.0) : 0.0,
      sellingPrice: (json['selling_price'] != null) ? (double.tryParse(json['selling_price'].toString()) ?? 0.0) : 0.0,
      discount: (json['discount'] != null) ? (double.tryParse(json['discount'].toString()) ?? 0.0) : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'medicine_id': medicineId,
        'medicine_name': medicineName,
        'barcode': barcode,
        'batch_number': batchNumber,
        'expiry_date': expiryDate.toIso8601String(),
        'quantity': quantity,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'discount': discount,
      };
}

class RemotePurchaseInvoice {
  final String invoiceNumber;
  final int? supplierId;
  final String supplierName;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String paymentType; // cash, credit
  final String? notes;
  final List<RemotePurchaseItem> items;
  final double totalAmount;
  final double discount;
  final double paidAmount;

  RemotePurchaseInvoice({
    required this.invoiceNumber,
    this.supplierId,
    required this.supplierName,
    required this.invoiceDate,
    this.dueDate,
    this.paymentType = 'cash',
    this.notes,
    required this.items,
    required this.totalAmount,
    this.discount = 0.0,
    required this.paidAmount,
  });

  factory RemotePurchaseInvoice.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<RemotePurchaseItem> parsed = [];
    if (rawItems is List) {
      parsed = rawItems.map((e) => RemotePurchaseItem.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    return RemotePurchaseInvoice(
      invoiceNumber: json['invoice_number'] ?? 'PUR-${DateTime.now().millisecondsSinceEpoch}',
      supplierId: json['supplier_id'] != null ? int.tryParse(json['supplier_id'].toString()) : null,
      supplierName: json['supplier_name'] ?? 'مورد عام',
      invoiceDate: json['invoice_date'] != null ? DateTime.tryParse(json['invoice_date']) ?? DateTime.now() : DateTime.now(),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      paymentType: json['payment_type'] ?? 'cash',
      notes: json['notes'],
      items: parsed,
      totalAmount: (json['total_amount'] != null) ? (double.tryParse(json['total_amount'].toString()) ?? 0.0) : 0.0,
      discount: (json['discount'] != null) ? (double.tryParse(json['discount'].toString()) ?? 0.0) : 0.0,
      paidAmount: (json['paid_amount'] != null) ? (double.tryParse(json['paid_amount'].toString()) ?? 0.0) : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'invoice_number': invoiceNumber,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'invoice_date': invoiceDate.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'payment_type': paymentType,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
        'total_amount': totalAmount,
        'discount': discount,
        'paid_amount': paidAmount,
      };
}

class ChatMessage {
  final String id;
  final int pharmacyId;
  final String? branchId;
  final String? deviceId;
  final String senderName;
  final String senderRole; // owner, cashier, pharmacist
  final String text;
  final String? audioBase64;
  final String? imageBase64;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.pharmacyId,
    this.branchId,
    this.deviceId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.audioBase64,
    this.imageBase64,
    this.imageUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id']?.toString() ?? '1') ?? 1,
      branchId: json['branch_id']?.toString(),
      deviceId: json['device_id']?.toString(),
      senderName: json['sender_name'] ?? 'مستخدم',
      senderRole: json['sender_role'] ?? 'cashier',
      text: json['text'] ?? '',
      audioBase64: json['audio_base64'],
      imageBase64: json['image_base64'],
      imageUrl: json['image_url'],
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pharmacy_id': pharmacyId,
        'branch_id': branchId,
        'device_id': deviceId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'text': text,
        'audio_base64': audioBase64,
        'image_base64': imageBase64,
        'image_url': imageUrl,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };
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
