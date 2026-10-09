// نماذج التواصل والأوامر الحية وبث الفيديو والدردشة وفواتير الشراء عن بعد - PharmaOS
import 'dart:convert';

class RemoteCommand {
  final String id;
  final int pharmacyId;
  final String? branchId;
  final String? deviceId;
  final String type; // backup, price_update, add_medicine, add_supplier, add_purchase_invoice, start_screen_stream, stop_screen_stream, start_camera_stream, stop_camera_stream
  final Map<String, dynamic> payload;
  final String status; // pending, executing, completed, failed
  final String? resultMessage;
  final DateTime createdAt;
  final DateTime? executedAt;

  RemoteCommand({
    required this.id,
    required this.pharmacyId,
    this.branchId,
    this.deviceId,
    required this.type,
    required this.payload,
    this.status = 'pending',
    this.resultMessage,
    required this.createdAt,
    this.executedAt,
  });

  factory RemoteCommand.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> payloadMap = {};
    final rawPayload = json['command_payload'] ?? json['payload'];
    if (rawPayload != null) {
      if (rawPayload is Map) {
        payloadMap = Map<String, dynamic>.from(rawPayload);
      } else if (rawPayload is String) {
        try {
          payloadMap = jsonDecode(rawPayload);
        } catch (_) {}
      }
    }

    return RemoteCommand(
      id: json['id']?.toString() ?? '',
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id']?.toString() ?? '1') ?? 1,
      branchId: json['branch_id']?.toString(),
      deviceId: json['device_id']?.toString(),
      type: json['command_type']?.toString() ?? json['type']?.toString() ?? 'unknown',
      payload: payloadMap,
      status: json['status']?.toString() ?? 'pending',
      resultMessage: json['error_message']?.toString() ?? json['result_message']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      executedAt: json['executed_at'] != null ? DateTime.tryParse(json['executed_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pharmacy_id': pharmacyId,
        'branch_id': branchId != null ? int.tryParse(branchId!) : null,
        'command_type': type,
        'command_payload': payload,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'executed_at': executedAt?.toIso8601String(),
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
    final sType = json['sender_type']?.toString() ?? json['sender_role']?.toString() ?? 'cashier';
    final isOwner = sType == 'owner';
    final msgText = json['message_text']?.toString() ?? json['text']?.toString() ?? '';
    final attach = json['attachment_url']?.toString() ?? json['image_url']?.toString();
    final isAudio = attach != null && attach.startsWith('data:audio');
    final isImage = attach != null && !isAudio;

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id']?.toString() ?? '1') ?? 1,
      branchId: json['branch_id']?.toString(),
      deviceId: json['device_id']?.toString(),
      senderName: isOwner ? 'المدير العام' : (json['sender_name'] ?? 'الصيدلي / الكاشير'),
      senderRole: sType,
      text: msgText,
      audioBase64: isAudio ? attach : json['audio_base64']?.toString(),
      imageBase64: isImage ? attach : json['image_base64']?.toString(),
      imageUrl: attach,
      isRead: json['read_at'] != null || json['is_read'] == true || json['is_read'] == 1,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pharmacy_id': pharmacyId,
        'branch_id': branchId != null ? int.tryParse(branchId!) : null,
        'sender_type': senderRole == 'owner' ? 'owner' : 'cashier',
        'message_text': text,
        'attachment_url': imageUrl ?? imageBase64 ?? audioBase64,
        'created_at': createdAt.toIso8601String(),
      };
}

class StreamFrame {
  final String id;
  final String channel; // screen, camera
  final int pharmacyId;
  final String branchId;
  final String deviceId;
  final String frameBase64;
  final int fps;
  final DateTime timestamp;

  StreamFrame({
    this.id = '',
    required this.channel,
    required this.pharmacyId,
    required this.branchId,
    required this.deviceId,
    required this.frameBase64,
    this.fps = 15,
    required this.timestamp,
  });

  factory StreamFrame.fromJson(Map<String, dynamic> json) {
    final rawFrame = json['frame_data']?.toString() ?? json['frame_base64']?.toString() ?? '';
    final rawTime = json['created_at'] ?? json['timestamp'];
    return StreamFrame(
      id: json['id']?.toString() ?? '',
      channel: json['channel']?.toString() ?? json['stream_type']?.toString() ?? 'screen',
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id']?.toString() ?? '2') ?? 2,
      branchId: json['branch_id']?.toString() ?? '2',
      deviceId: json['device_id']?.toString() ?? 'dev-1',
      frameBase64: rawFrame,
      fps: json['fps'] is int ? json['fps'] : int.tryParse(json['fps']?.toString() ?? '15') ?? 15,
      timestamp: rawTime != null ? DateTime.tryParse(rawTime.toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'pharmacy_id': pharmacyId,
      'branch_id': int.tryParse(branchId) ?? 2,
      'stream_type': channel,
      'channel': channel,
      'frame_data': frameBase64,
      'created_at': timestamp.toIso8601String(),
    };
    if (id.isNotEmpty && id.contains('-') && id.length == 36) {
      map['id'] = id;
    }
    return map;
  }
}

class RemotePurchaseItemPayload {
  final int? medicineId;
  final String medicineName;
  final String? barcode;
  final String batchNumber;
  final DateTime expiryDate;
  final int quantity;
  final double purchasePrice;
  final double sellingPrice;
  final double discount;

  RemotePurchaseItemPayload({
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

  factory RemotePurchaseItemPayload.fromJson(Map<String, dynamic> json) {
    return RemotePurchaseItemPayload(
      medicineId: json['medicine_id'] != null ? int.tryParse(json['medicine_id'].toString()) : null,
      medicineName: json['medicine_name'] ?? 'صنف جديد',
      barcode: json['barcode'],
      batchNumber: json['batch_number'] ?? 'BATCH-${DateTime.now().millisecondsSinceEpoch}',
      expiryDate: json['expiry_date'] != null ? DateTime.tryParse(json['expiry_date']) ?? DateTime.now().add(const Duration(days: 365)) : DateTime.now().add(const Duration(days: 365)),
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

class RemotePurchaseInvoicePayload {
  final String invoiceNumber;
  final int? supplierId;
  final String supplierName;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String paymentType; // cash, credit
  final String? notes;
  final List<RemotePurchaseItemPayload> items;
  final double totalAmount;
  final double discount;
  final double paidAmount;

  RemotePurchaseInvoicePayload({
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

  factory RemotePurchaseInvoicePayload.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<RemotePurchaseItemPayload> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems.map((i) => RemotePurchaseItemPayload.fromJson(Map<String, dynamic>.from(i))).toList();
    }

    return RemotePurchaseInvoicePayload(
      invoiceNumber: json['invoice_number'] ?? 'PUR-${DateTime.now().millisecondsSinceEpoch}',
      supplierId: json['supplier_id'] != null ? int.tryParse(json['supplier_id'].toString()) : null,
      supplierName: json['supplier_name'] ?? 'مورد عام',
      invoiceDate: json['invoice_date'] != null ? DateTime.tryParse(json['invoice_date']) ?? DateTime.now() : DateTime.now(),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      paymentType: json['payment_type'] ?? 'cash',
      notes: json['notes'],
      items: parsedItems,
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

class OwnerAuditAction {
  final String id;
  final int pharmacyId;
  final String actionType; // price_changed, medicine_added, supplier_added, purchase_recorded, backup_triggered, chat_received
  final String title;
  final String description;
  final String performedBy;
  final DateTime createdAt;

  OwnerAuditAction({
    required this.id,
    required this.pharmacyId,
    required this.actionType,
    required this.title,
    required this.description,
    required this.performedBy,
    required this.createdAt,
  });

  factory OwnerAuditAction.fromJson(Map<String, dynamic> json) {
    return OwnerAuditAction(
      id: json['id']?.toString() ?? 'act-${DateTime.now().millisecondsSinceEpoch}',
      pharmacyId: json['pharmacy_id'] is int ? json['pharmacy_id'] : int.tryParse(json['pharmacy_id']?.toString() ?? '1') ?? 1,
      actionType: json['action_type'] ?? 'general',
      title: json['title'] ?? 'إجراء إداري',
      description: json['description'] ?? '',
      performedBy: json['performed_by'] ?? 'المدير العام',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pharmacy_id': pharmacyId,
        'action_type': actionType,
        'title': title,
        'description': description,
        'performed_by': performedBy,
        'created_at': createdAt.toIso8601String(),
      };
}
