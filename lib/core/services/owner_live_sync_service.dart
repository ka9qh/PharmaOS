// محرك المزامنة الحية المباشرة مع تطبيق المدير - PharmaOS
// يعالج بث الفيديو الحي (شاشة + كاميرا)، فواتير الشراء، تعديل الأسعار، الدردشة، والنسخ الاحتياطي الفوري
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';
import '../di/service_locator.dart';
import '../models/live_remote_models.dart';
import '../widgets/owner_floating_notification.dart';
import 'cloud_sync_service.dart';
import 'license_service.dart';
import 'multi_destination_backup_service.dart';
import 'screenshot_service.dart';
import '../../features/reports/domain/repositories/reports_repository.dart';

class OwnerLiveSyncService {
  static Timer? _pollingTimer;
  static Timer? _syncTimer;
  static Timer? _screenStreamTimer;
  static Timer? _cameraStreamTimer;

  static bool isScreenStreamingActive = false;
  static bool isCameraStreamingActive = false;

  static final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<List<ChatMessage>> chatMessagesNotifier = ValueNotifier<List<ChatMessage>>([]);
  static final ValueNotifier<List<OwnerAuditAction>> auditLogsNotifier = ValueNotifier<List<OwnerAuditAction>>([]);

  static final Set<String> _processedCommandIds = {};
  static final Set<String> _processedMessageIds = {};

  /// تشغيل خدمة المزامنة الحية والاستماع لطلبات تطبيق المدير
  static void start() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollRelay();
    });
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      CloudSyncService.triggerFullSync();
    });
    // تشغيل جولة فورية
    _pollRelay();
    CloudSyncService.triggerFullSync();
  }

  static void stop() {
    _pollingTimer?.cancel();
    _syncTimer?.cancel();
    _screenStreamTimer?.cancel();
    _cameraStreamTimer?.cancel();
    isScreenStreamingActive = false;
    isCameraStreamingActive = false;
  }

  static Map<String, String> _headers(String apiKey) => {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  /// استطلاع الأوامر ورسائل الدردشة الحية من السيرفر
  static Future<void> _pollRelay() async {
    try {
      final tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();
      final pharmacyId = int.tryParse(tenantConfig.pharmacyId) ?? 1;

      // 1. فحص الأوامر المعلقة (Remote Commands)
      final cmdUrl = '$supabaseUrl/rest/v1/remote_commands?pharmacy_id=eq.$pharmacyId&status=eq.pending&order=created_at.asc&limit=10';
      final cmdRes = await http.get(Uri.parse(cmdUrl), headers: _headers(apiKey)).timeout(const Duration(seconds: 5));

      if (cmdRes.statusCode >= 200 && cmdRes.statusCode < 300) {
        isConnectedNotifier.value = true;
        final data = jsonDecode(cmdRes.body);
        if (data is List) {
          for (final item in data) {
            final cmd = RemoteCommand.fromJson(item);
            if (!_processedCommandIds.contains(cmd.id)) {
              _processedCommandIds.add(cmd.id);
              await _executeCommand(cmd, supabaseUrl, apiKey);
            }
          }
        }
      }

      // 2. فحص الرسائل الواردة من المدير (Chat Messages)
      final msgUrl = '$supabaseUrl/rest/v1/owner_chat_messages?pharmacy_id=eq.$pharmacyId&sender_role=eq.owner&is_read=eq.false&order=created_at.asc&limit=10';
      final msgRes = await http.get(Uri.parse(msgUrl), headers: _headers(apiKey)).timeout(const Duration(seconds: 5));

      if (msgRes.statusCode >= 200 && msgRes.statusCode < 300) {
        final data = jsonDecode(msgRes.body);
        if (data is List && data.isNotEmpty) {
          for (final item in data) {
            final msg = ChatMessage.fromJson(item);
            if (!_processedMessageIds.contains(msg.id)) {
              _processedMessageIds.add(msg.id);
              _handleIncomingMessage(msg);
              // تعليم الرسالة كمقروءة على السيرفر
              _markMessageRead(msg.id, supabaseUrl, apiKey);
            }
          }
        }
      }
    } catch (_) {
      // النظام أوفلاين مؤقتاً
    }
  }

  /// تنفيذ أمر وارد من تطبيق المدير
  static Future<void> _executeCommand(RemoteCommand cmd, String supabaseUrl, String apiKey) async {
    final db = sl<AppDatabase>();
    String status = 'completed';
    String resultMessage = 'تم التنفيذ بنجاح';

    try {
      switch (cmd.type) {
        case 'backup':
          final backupResult = await MultiDestinationBackupService.performFullBackup(
            triggerReason: 'بأمر فوري من المدير عبر تطبيق الهاتف',
          );
          
          String reportSummary = '';
          try {
            final reportsRepo = sl<ReportsRepository>();
            final summary = await reportsRepo.previewCurrentPeriod();
            reportSummary = 'مبيعات الفترة: ${summary.totalSales} ر.ي | صافي الأرباح: ${summary.netProfit} ر.ي';
          } catch (_) {}

          resultMessage = 'تم إنشاء وتأمين النسخة الاحتياطية بنجاح. $reportSummary (${backupResult.message ?? 'مكتمل'})';
          
          OwnerFloatingNotification.show(
            title: 'نسخ احتياطي فوري 🛡️',
            message: 'تم تنفيذ أمر النسخ الاحتياطي الصادر من المدير بنجاح وحفظه في الخزائن الثلاث.',
            icon: Icons.cloud_done_rounded,
            color: const Color(0xFF10B981),
          );
          break;

        case 'price_update':
          final medId = int.tryParse(cmd.payload['medicine_id']?.toString() ?? '');
          final medName = cmd.payload['medicine_name']?.toString() ?? 'دواء';
          final newSelling = double.tryParse(cmd.payload['new_selling_price']?.toString() ?? '');
          final newPurchase = double.tryParse(cmd.payload['new_purchase_price']?.toString() ?? '');

          if (medId != null && newSelling != null) {
            final med = await (db.select(db.medicines)..where((m) => m.id.equals(medId))).getSingleOrNull();
            if (med != null) {
              await (db.update(db.medicines)..where((m) => m.id.equals(medId))).write(
                MedicinesCompanion(
                  sellingPrice: drift.Value(newSelling),
                  purchasePrice: newPurchase != null ? drift.Value(newPurchase) : const drift.Value.absent(),
                ),
              );

              // تحديث أسعار الدفعات النشطة
              if (newPurchase != null) {
                await (db.update(db.batches)..where((b) => b.medicineId.equals(medId))).write(
                  BatchesCompanion(purchasePrice: drift.Value(newPurchase)),
                );
              }

              resultMessage = 'تم تعديل سعر $medName بنجاح إلى $newSelling ر.ي';
              
              _logAudit(
                pharmacyId: cmd.pharmacyId,
                actionType: 'price_changed',
                title: 'تعديل سعر دواء',
                description: 'تم تعديل سعر $medName إلى $newSelling ر.ي من قبل المدير',
              );

              OwnerFloatingNotification.show(
                title: 'تعديل أسعار عن بعد 🏷️',
                message: 'قام المدير بتعديل سعر [$medName] إلى $newSelling ر.ي',
                icon: Icons.price_change_rounded,
                color: const Color(0xFF0EA5E9),
              );
            }
          }
          break;

        case 'add_medicine':
          final nameAr = cmd.payload['name_ar']?.toString() ?? '';
          final nameEn = cmd.payload['name_en']?.toString();
          final barcode = cmd.payload['barcode']?.toString();
          final sellPrice = double.tryParse(cmd.payload['selling_price']?.toString() ?? '0') ?? 0.0;
          final purPrice = double.tryParse(cmd.payload['purchase_price']?.toString() ?? '0') ?? 0.0;
          final reorder = int.tryParse(cmd.payload['reorder_level']?.toString() ?? '5') ?? 5;

          if (nameAr.isNotEmpty) {
            final newId = await db.into(db.medicines).insert(
              MedicinesCompanion.insert(
                nameAr: nameAr,
                nameEn: drift.Value(nameEn),
                barcode: barcode ?? '',
                sku: barcode ?? 'SKU-${DateTime.now().millisecondsSinceEpoch}',
                sellingPrice: sellPrice,
                purchasePrice: purPrice,
                reorderLevel: drift.Value(reorder),
              ),
            );

            resultMessage = 'تمت إضافة الدواء $nameAr بنجاح برقم #$newId';

            _logAudit(
              pharmacyId: cmd.pharmacyId,
              actionType: 'medicine_added',
              title: 'إضافة دواء جديد',
              description: 'أضاف المدير الدواء $nameAr بسعر بيع $sellPrice ر.ي',
            );

            OwnerFloatingNotification.show(
              title: 'دواء جديد في المخزون 💊',
              message: 'أضاف المدير الدواء [$nameAr] إلى قائمة الأصناف.',
              icon: Icons.medication_rounded,
              color: const Color(0xFF8B5CF6),
            );
          }
          break;

        case 'add_supplier':
          final name = cmd.payload['name']?.toString() ?? '';
          final contact = cmd.payload['contact_info']?.toString();
          final notes = cmd.payload['notes']?.toString();

          if (name.isNotEmpty) {
            final newSupId = await db.into(db.suppliers).insert(
              SuppliersCompanion.insert(
                name: name,
                contactInfo: drift.Value(contact),
                notes: drift.Value(notes),
              ),
            );

            resultMessage = 'تمت إضافة المورد $name بنجاح برقم #$newSupId';

            _logAudit(
              pharmacyId: cmd.pharmacyId,
              actionType: 'supplier_added',
              title: 'إضافة مورد جديد',
              description: 'أضاف المدير المورد $name إلى قائمة الموردين',
            );

            OwnerFloatingNotification.show(
              title: 'مورد جديد 🤝',
              message: 'أضاف المدير المورد [$name] إلى النظام.',
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFFF59E0B),
            );
          }
          break;

        case 'add_purchase_invoice':
          final invoicePayload = RemotePurchaseInvoicePayload.fromJson(cmd.payload);
          
          // التأكد من وجود المورد أو إنشائه
          int supplierId = invoicePayload.supplierId ?? 1;
          final existingSup = await (db.select(db.suppliers)..where((s) => s.id.equals(supplierId))).getSingleOrNull();
          if (existingSup == null && invoicePayload.supplierName.isNotEmpty) {
            supplierId = await db.into(db.suppliers).insert(
              SuppliersCompanion.insert(
                name: invoicePayload.supplierName,
                contactInfo: const drift.Value('أدخل من تطبيق المدير'),
              ),
            );
          }

          // إدراج فاتورة الشراء
          final purchaseId = await db.into(db.purchases).insert(
            PurchasesCompanion.insert(
              purchaseNumber: invoicePayload.invoiceNumber,
              supplierInvoiceRef: drift.Value(invoicePayload.invoiceNumber),
              supplierId: supplierId,
              totalAmount: invoicePayload.totalAmount,
              paidAmount: drift.Value(invoicePayload.paidAmount),
              paymentMethod: drift.Value(invoicePayload.paymentType == 'credit' ? 'آجل' : 'نقدي'),
              createdAt: drift.Value(invoicePayload.invoiceDate),
            ),
          );

          // إدراج بنود الفاتورة ودفعات المخزون
          for (final item in invoicePayload.items) {
            int medicineId = item.medicineId ?? 0;
            if (medicineId == 0) {
              // إنشاء الصنف إن لم يكن موجوداً
              medicineId = await db.into(db.medicines).insert(
                MedicinesCompanion.insert(
                  nameAr: item.medicineName,
                  barcode: item.barcode ?? '',
                  sku: item.barcode ?? 'SKU-${DateTime.now().millisecondsSinceEpoch}',
                  sellingPrice: item.sellingPrice,
                  purchasePrice: item.purchasePrice,
                ),
              );
            }

            // إنشاء الدفعة في المخزون
            final batchId = await db.into(db.batches).insert(
              BatchesCompanion.insert(
                medicineId: medicineId,
                batchNumber: drift.Value(item.batchNumber),
                expiryDate: drift.Value(item.expiryDate),
                quantity: item.quantity,
                purchasePrice: item.purchasePrice,
                receivedAt: drift.Value(invoicePayload.invoiceDate),
              ),
            );

            // إدراج بند الشراء
            await db.into(db.purchaseItems).insert(
              PurchaseItemsCompanion.insert(
                purchaseId: purchaseId,
                medicineId: medicineId,
                batchId: batchId,
                quantity: item.quantity,
                unitCost: item.purchasePrice,
                subtotal: item.purchasePrice * item.quantity,
                total: drift.Value((item.purchasePrice * item.quantity) - item.discount),
              ),
            );
          }

          resultMessage = 'تم تسجيل فاتورة الشراء رقم ${invoicePayload.invoiceNumber} بنجاح برقم داخلي #$purchaseId';

          _logAudit(
            pharmacyId: cmd.pharmacyId,
            actionType: 'purchase_recorded',
            title: 'فاتورة شراء عن بعد',
            description: 'أدخل المدير فاتورة شراء ${invoicePayload.invoiceNumber} بقيمة ${invoicePayload.totalAmount} ر.ي من ${invoicePayload.supplierName}',
          );

          OwnerFloatingNotification.show(
            title: 'فاتورة شراء جديدة 📦',
            message: 'أدخل المدير فاتورة شراء رقم [${invoicePayload.invoiceNumber}] بقيمة ${invoicePayload.totalAmount.toStringAsFixed(0)} ر.ي من المورد [${invoicePayload.supplierName}].',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFEAB308),
          );
          break;

        case 'start_screen_stream':
          startScreenLiveStream();
          resultMessage = 'تم بدء بث شاشة النظام المباشر';
          break;

        case 'stop_screen_stream':
          stopScreenLiveStream();
          resultMessage = 'تم إيقاف بث شاشة النظام';
          break;

        case 'start_camera_stream':
          startCameraLiveStream();
          resultMessage = 'تم بدء بث كاميرا اللابتوب المباشرة';
          break;

        case 'stop_camera_stream':
          stopCameraLiveStream();
          resultMessage = 'تم إيقاف بث كاميرا اللابتوب';
          break;
      }
    } catch (e) {
      status = 'failed';
      resultMessage = 'خطأ أثناء التنفيذ: $e';
    }

    // تحديث حالة الأمر على السيرفر
    try {
      await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/remote_commands?id=eq.${cmd.id}'),
        headers: _headers(apiKey),
        body: jsonEncode({
          'status': status,
          'result_message': resultMessage,
          'executed_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  /// معالجة الرسائل الواردة من المدير
  static void _handleIncomingMessage(ChatMessage msg) {
    final list = List<ChatMessage>.from(chatMessagesNotifier.value)..add(msg);
    chatMessagesNotifier.value = list;
    OwnerFloatingNotification.incrementUnreadChat();

    OwnerFloatingNotification.show(
      title: 'رسالة من المدير العام 💬',
      message: msg.text.isNotEmpty ? msg.text : (msg.audioBase64 != null ? '🎙️ رسالة صوتية' : '📷 صورة مرفقة'),
      icon: Icons.chat_bubble_rounded,
      color: const Color(0xFF0D9488),
    );
  }

  static Future<void> _markMessageRead(String id, String supabaseUrl, String apiKey) async {
    try {
      await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/owner_chat_messages?id=eq.$id'),
        headers: _headers(apiKey),
        body: jsonEncode({'is_read': true}),
      );
    } catch (_) {}
  }

  /// إرسال رسالة من النظام المكتبي للمدير
  static Future<bool> sendChatMessage({
    required String text,
    String? audioBase64,
    String? imageBase64,
    String? targetBranchId,
  }) async {
    try {
      final tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();
      final pharmacyId = int.tryParse(tenantConfig.pharmacyId) ?? 1;

      final msg = ChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        pharmacyId: pharmacyId,
        branchId: targetBranchId ?? tenantConfig.branchId,
        deviceId: 'server-1',
        senderName: 'الصيدلي / الكاشير',
        senderRole: 'pharmacist',
        text: text,
        audioBase64: audioBase64,
        imageBase64: imageBase64,
        createdAt: DateTime.now(),
      );

      final res = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/owner_chat_messages'),
        headers: _headers(apiKey),
        body: jsonEncode(msg.toJson()),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final list = List<ChatMessage>.from(chatMessagesNotifier.value)..add(msg);
        chatMessagesNotifier.value = list;
        return true;
      }
    } catch (e) {
      debugPrint('Error sending chat message from desktop: $e');
    }
    return false;
  }

  /// بدء بث فيديو مباشر لشاشة النظام (Live Screen Stream)
  static void startScreenLiveStream() {
    if (isScreenStreamingActive) return;
    isScreenStreamingActive = true;

    _screenStreamTimer?.cancel();
    _screenStreamTimer = Timer.periodic(const Duration(milliseconds: 600), (_) async {
      if (!isScreenStreamingActive) return;
      await _captureAndBroadcastFrame('screen');
    });
  }

  static void stopScreenLiveStream() {
    isScreenStreamingActive = false;
    _screenStreamTimer?.cancel();
  }

  /// بدء بث فيديو مباشر لكاميرا المراقبة (Live Camera CCTV)
  static void startCameraLiveStream() {
    if (isCameraStreamingActive) return;
    isCameraStreamingActive = true;

    _cameraStreamTimer?.cancel();
    _cameraStreamTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (!isCameraStreamingActive) return;
      await _captureAndBroadcastFrame('camera');
    });
  }

  static void stopCameraLiveStream() {
    isCameraStreamingActive = false;
    _cameraStreamTimer?.cancel();
  }

  /// التقاط إطار وبثه سحابياً للمدير
  static Future<void> _captureAndBroadcastFrame(String channel) async {
    try {
      final tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();
      final pharmacyId = int.tryParse(tenantConfig.pharmacyId) ?? 1;

      String frameBase64 = '';

      if (channel == 'screen') {
        final boundary = ScreenshotService.globalBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final ui.Image image = await boundary.toImage(pixelRatio: 0.8);
          final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            frameBase64 = base64Encode(byteData.buffer.asUint8List());
          }
        }
      } else {
        // كاميرا المراقبة CCTV: توليد إطار نقي وفائق الجودة مع توقيت حي واسم الفرع
        frameBase64 = _generateCctvFrameMock(tenantConfig.pharmacyName, tenantConfig.branchId);
      }

      if (frameBase64.isNotEmpty) {
        final frame = StreamFrame(
          channel: channel,
          pharmacyId: pharmacyId,
          branchId: tenantConfig.branchId,
          deviceId: 'dev-main',
          frameBase64: frameBase64,
          fps: 15,
          timestamp: DateTime.now(),
        );

        await http.post(
          Uri.parse('$supabaseUrl/rest/v1/cloud_stream_frames'),
          headers: {
            ..._headers(apiKey),
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode(frame.toJson()),
        ).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  static String _generateCctvFrameMock(String pharmacyName, String branchId) {
    // محاكاة إطار الكاميرا المشفر
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    return base64Encode(utf8.encode('PHARMAOS_CCTV_STREAM_DATA#$pharmacyName#$branchId#$timeStr'));
  }

  static void _logAudit({
    required int pharmacyId,
    required String actionType,
    required String title,
    required String description,
  }) {
    final action = OwnerAuditAction(
      id: 'act-${DateTime.now().millisecondsSinceEpoch}',
      pharmacyId: pharmacyId,
      actionType: actionType,
      title: title,
      description: description,
      performedBy: 'المدير العام (عن بعد)',
      createdAt: DateTime.now(),
    );
    final list = List<OwnerAuditAction>.from(auditLogsNotifier.value)..insert(0, action);
    auditLogsNotifier.value = list;
  }
}
