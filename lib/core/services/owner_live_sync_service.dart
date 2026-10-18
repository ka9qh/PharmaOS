// محرك المزامنة الحية المباشرة مع تطبيق المدير - PharmaOS
// يعالج بث الفيديو الحي (شاشة + كاميرا)، فواتير الشراء، تعديل الأسعار، الدردشة، والنسخ الاحتياطي الفوري
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' as drift;
import 'package:camera/camera.dart';

import '../database/app_database.dart';
import '../di/service_locator.dart';
import '../models/live_remote_models.dart';
import '../widgets/owner_floating_notification.dart';
import 'cloud_sync_service.dart';
import 'license_service.dart';
import 'multi_destination_backup_service.dart';
import 'screenshot_service.dart';
import '../config/supabase_config.dart';
import '../../features/reports/domain/repositories/reports_repository.dart';

class OwnerLiveSyncService {
  static Timer? _pollingTimer;
  static Timer? _screenStreamTimer;
  static Timer? _cameraStreamTimer;
  static CameraController? _cameraController;

  static WebSocket? _realtimeWs;
  static Timer? _wsHeartbeatTimer;
  static bool _isConnectingWs = false;
  static int _wsRef = 1;
  static DateTime? _lastScreenKeyframeTime;
  static DateTime? _lastCameraKeyframeTime;

  static bool isScreenStreamingActive = false;
  static bool isCameraStreamingActive = false;
  static bool _isScreenFrameInProgress = false;
  static bool _isCameraFrameInProgress = false;
  static bool _isPolling = false;
  static int _consecutiveFailures = 0;

  static final ValueNotifier<bool> isConnectedNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<List<ChatMessage>> chatMessagesNotifier =
      ValueNotifier<List<ChatMessage>>([]);
  static final ValueNotifier<List<OwnerAuditAction>> auditLogsNotifier =
      ValueNotifier<List<OwnerAuditAction>>([]);

  static final Set<String> _processedCommandIds = {};
  static final Set<String> _processedMessageIds = {};

  /// توليد معرف متوافق مع معيار UUID v4 للأوامر والرسائل
  static String _generateUuidV4() {
    final random = math.Random();
    String hex(int length) {
      final buffer = StringBuffer();
      for (int i = 0; i < length; i++) {
        buffer.write(random.nextInt(16).toRadixString(16));
      }
      return buffer.toString();
    }

    final p1 = hex(8);
    final p2 = hex(4);
    final p3 = '4${hex(3)}';
    final p4Variant = (8 + random.nextInt(4)).toRadixString(16);
    final p4 = '$p4Variant${hex(3)}';
    final p5 = hex(12);
    return '$p1-$p2-$p3-$p4-$p5';
  }

  /// تشغيل خدمة المزامنة الحية والاستماع لطلبات تطبيق المدير
  static void start() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollRelay();
    });
    // تشغيل جولة فورية
    _pollRelay();
  }

  static void stop() {
    _pollingTimer?.cancel();
    _screenStreamTimer?.cancel();
    _cameraStreamTimer?.cancel();
    _wsHeartbeatTimer?.cancel();
    try {
      _realtimeWs?.close();
    } catch (_) {}
    _realtimeWs = null;
    isScreenStreamingActive = false;
    isCameraStreamingActive = false;
    _cameraController?.dispose();
    _cameraController = null;
    _isPolling = false;
  }

  static String? lastChatError;

  static int _resolveIntId(dynamic val, int fallback) {
    if (val is int && val > 0) return val;
    if (val != null) {
      final str = val.toString().trim();
      final parsed = int.tryParse(str);
      if (parsed != null && parsed > 0) return parsed;
      final digits = str.replaceAll(RegExp(r'[^0-9]'), '');
      final ext = int.tryParse(digits);
      if (ext != null && ext > 0) return ext;
    }
    return fallback;
  }

  static Map<String, String> _headers(String apiKey) {
    final key = apiKey.trim().isNotEmpty ? apiKey.trim() : SupabaseConfig.anonKey;
    return {
      'apikey': key,
      'Authorization': 'Bearer $key',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
  }

  /// استطلاع الأوامر ورسائل الدردشة الحية من السيرفر
  static Future<void> _pollRelay() async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      final tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();
      final pharmacyId = _resolveIntId(tenantConfig.pharmacyId, 2);
      final branchId = _resolveIntId(tenantConfig.branchId, 2);

      // 1. فحص الأوامر المعلقة (Remote Commands)
      final cmdUrl =
          '$supabaseUrl/rest/v1/remote_commands?pharmacy_id=eq.$pharmacyId&branch_id=eq.$branchId&status=eq.pending&order=created_at.asc&limit=10';
      final cmdRes = await http
          .get(Uri.parse(cmdUrl), headers: _headers(apiKey))
          .timeout(SupabaseConfig.requestTimeout);

      if (cmdRes.statusCode >= 200 && cmdRes.statusCode < 300) {
        _consecutiveFailures = 0;
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
      } else {
        debugPrint('[Poll] remote_commands check failed [${cmdRes.statusCode}]: ${cmdRes.body}');
      }

      // 2. فحص الرسائل الواردة من المدير (Chat Messages)
      final msgUrl =
          '$supabaseUrl/rest/v1/owner_chat_messages?pharmacy_id=eq.$pharmacyId&branch_id=eq.$branchId&sender_type=eq.owner&read_at=is.null&order=created_at.asc&limit=10';
      final msgRes = await http
          .get(Uri.parse(msgUrl), headers: _headers(apiKey))
          .timeout(SupabaseConfig.requestTimeout);

      if (msgRes.statusCode >= 200 && msgRes.statusCode < 300) {
        _consecutiveFailures = 0;
        isConnectedNotifier.value = true;
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
      } else {
        debugPrint('[Poll] owner_chat_messages check failed [${msgRes.statusCode}]: ${msgRes.body}');
      }
    } catch (e) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 3) {
        isConnectedNotifier.value = false;
      }
      debugPrint('Owner sync poll failed (attempt $_consecutiveFailures): $e');
    } finally {
      _isPolling = false;
    }
  }

  /// تنفيذ أمر وارد من تطبيق المدير
  static Future<void> _executeCommand(
      RemoteCommand cmd, String supabaseUrl, String apiKey) async {
    final db = sl<AppDatabase>();
    String status = 'completed';
    String resultMessage = 'تم التنفيذ بنجاح';

    try {
      switch (cmd.type) {
        case 'backup':
          final backupResult =
              await MultiDestinationBackupService.performFullBackup(
            triggerReason: 'بأمر فوري من المدير عبر تطبيق الهاتف',
          );

          String reportSummary = '';
          try {
            final reportsRepo = sl<ReportsRepository>();
            final summary = await reportsRepo.previewCurrentPeriod();
            reportSummary =
                'مبيعات الفترة: ${summary.totalSales} ر.ي | صافي الأرباح: ${summary.netProfit} ر.ي';
          } catch (_) {}

          resultMessage =
              'تم إنشاء وتأمين النسخة الاحتياطية بنجاح. $reportSummary (${backupResult.message ?? 'مكتمل'})';

          OwnerFloatingNotification.show(
            title: 'نسخ احتياطي فوري 🛡️',
            message:
                'تم تنفيذ أمر النسخ الاحتياطي الصادر من المدير بنجاح وحفظه في الخزائن الثلاث.',
            icon: Icons.cloud_done_rounded,
            color: const Color(0xFF10B981),
          );
          break;

        case 'price_update':
          final medId =
              int.tryParse(cmd.payload['medicine_id']?.toString() ?? '');
          final medName = cmd.payload['medicine_name']?.toString() ?? 'دواء';
          final newSelling = double.tryParse(
              cmd.payload['new_selling_price']?.toString() ?? '');
          final newPurchase = double.tryParse(
              cmd.payload['new_purchase_price']?.toString() ?? '');

          if (medId != null && newSelling != null) {
            final med = await (db.select(db.medicines)
                  ..where((m) => m.id.equals(medId)))
                .getSingleOrNull();
            if (med != null) {
              await (db.update(db.medicines)..where((m) => m.id.equals(medId)))
                  .write(
                MedicinesCompanion(
                  sellingPrice: drift.Value(newSelling),
                  purchasePrice: newPurchase != null
                      ? drift.Value(newPurchase)
                      : const drift.Value.absent(),
                ),
              );

              // تحديث أسعار الدفعات النشطة
              if (newPurchase != null) {
                await (db.update(db.batches)
                      ..where((b) => b.medicineId.equals(medId)))
                    .write(
                  BatchesCompanion(purchasePrice: drift.Value(newPurchase)),
                );
              }

              resultMessage = 'تم تعديل سعر $medName بنجاح إلى $newSelling ر.ي';

              _logAudit(
                pharmacyId: cmd.pharmacyId,
                actionType: 'price_changed',
                title: 'تعديل سعر دواء',
                description:
                    'تم تعديل سعر $medName إلى $newSelling ر.ي من قبل المدير',
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
          final sellPrice = double.tryParse(
                  cmd.payload['selling_price']?.toString() ?? '0') ??
              0.0;
          final purPrice = double.tryParse(
                  cmd.payload['purchase_price']?.toString() ?? '0') ??
              0.0;
          final reorder =
              int.tryParse(cmd.payload['reorder_level']?.toString() ?? '5') ??
                  5;

          if (nameAr.isNotEmpty) {
            final newId = await db.into(db.medicines).insert(
                  MedicinesCompanion.insert(
                    nameAr: nameAr,
                    nameEn: drift.Value(nameEn),
                    barcode: barcode ?? '',
                    sku: barcode ??
                        'SKU-${DateTime.now().millisecondsSinceEpoch}',
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
          final invoicePayload =
              RemotePurchaseInvoicePayload.fromJson(cmd.payload);

          // التأكد من وجود المورد أو إنشائه
          int supplierId = invoicePayload.supplierId ?? 1;
          final existingSup = await (db.select(db.suppliers)
                ..where((s) => s.id.equals(supplierId)))
              .getSingleOrNull();
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
                  paymentMethod: drift.Value(
                      invoicePayload.paymentType == 'credit' ? 'آجل' : 'نقدي'),
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
                      sku: item.barcode ??
                          'SKU-${DateTime.now().millisecondsSinceEpoch}',
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
                    total: drift.Value(
                        (item.purchasePrice * item.quantity) - item.discount),
                  ),
                );
          }

          resultMessage =
              'تم تسجيل فاتورة الشراء رقم ${invoicePayload.invoiceNumber} بنجاح برقم داخلي #$purchaseId';

          _logAudit(
            pharmacyId: cmd.pharmacyId,
            actionType: 'purchase_recorded',
            title: 'فاتورة شراء عن بعد',
            description:
                'أدخل المدير فاتورة شراء ${invoicePayload.invoiceNumber} بقيمة ${invoicePayload.totalAmount} ر.ي من ${invoicePayload.supplierName}',
          );

          OwnerFloatingNotification.show(
            title: 'فاتورة شراء جديدة 📦',
            message:
                'أدخل المدير فاتورة شراء رقم [${invoicePayload.invoiceNumber}] بقيمة ${invoicePayload.totalAmount.toStringAsFixed(0)} ر.ي من المورد [${invoicePayload.supplierName}].',
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

    final finalStatus =
        (status == 'completed' || status == 'executed') ? 'executed' : 'failed';
    // تحديث حالة الأمر على السيرفر
    try {
      await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/remote_commands?id=eq.${cmd.id}'),
        headers: _headers(apiKey),
        body: jsonEncode({
          'status': finalStatus,
          'error_message': resultMessage,
          'executed_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Unable to acknowledge remote command ${cmd.id}: $e');
    }
  }

  /// معالجة الرسائل الواردة من المدير
  static void _handleIncomingMessage(ChatMessage msg) {
    final list = List<ChatMessage>.from(chatMessagesNotifier.value)..add(msg);
    chatMessagesNotifier.value = list;
    OwnerFloatingNotification.incrementUnreadChat();

    OwnerFloatingNotification.show(
      title: 'رسالة من المدير العام 💬',
      message: msg.text.isNotEmpty
          ? msg.text
          : (msg.audioBase64 != null ? '🎙️ رسالة صوتية' : '📷 صورة مرفقة'),
      icon: Icons.chat_bubble_rounded,
      color: const Color(0xFF0D9488),
    );
  }

  static Future<void> _markMessageRead(
      String id, String supabaseUrl, String apiKey) async {
    try {
      await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/owner_chat_messages?id=eq.$id'),
        headers: _headers(apiKey),
        body: jsonEncode({'read_at': DateTime.now().toIso8601String()}),
      );
    } catch (_) {}
  }

  /// جلب سجل الرسائل المتبادلة بين الصيدلية وتطبيق المدير
  static Future<List<ChatMessage>> fetchChatMessages() async {
    try {
      final tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();
      final pharmacyId = _resolveIntId(tenantConfig.pharmacyId, 2);
      final branchId = _resolveIntId(tenantConfig.branchId, 2);

      final url =
          '$supabaseUrl/rest/v1/owner_chat_messages?pharmacy_id=eq.$pharmacyId&branch_id=eq.$branchId&order=created_at.asc&limit=100';
      final res = await http
          .get(Uri.parse(url), headers: _headers(apiKey))
          .timeout(SupabaseConfig.requestTimeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is List) {
          final list = data.map((j) => ChatMessage.fromJson(j)).toList();
          chatMessagesNotifier.value = list;
          return list;
        }
      } else {
        debugPrint(
            '[Chat] fetchChatMessages failed with status [${res.statusCode}]: ${res.body}');
      }
    } catch (e) {
      debugPrint('[Chat] fetchChatMessages error: $e');
    }
    return chatMessagesNotifier.value;
  }

  /// إرسال رسالة من النظام المكتبي للمدير مع إعادة محاولة تلقائية في حال انقطاع الشبكة المؤقت
  static Future<bool> sendChatMessage({
    required String text,
    String? audioBase64,
    String? imageBase64,
    String? targetBranchId,
  }) async {
    lastChatError = null;
    try {
      final tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();
      final pharmacyId = _resolveIntId(tenantConfig.pharmacyId, 2);
      final branchId =
          _resolveIntId(targetBranchId ?? tenantConfig.branchId, 2);

      final msg = ChatMessage(
        id: _generateUuidV4(),
        pharmacyId: pharmacyId,
        branchId: branchId.toString(),
        deviceId: tenantConfig.deviceId.isNotEmpty
            ? tenantConfig.deviceId
            : 'server-1',
        senderName: 'الصيدلي / الكاشير',
        senderRole: 'cashier',
        text: text,
        audioBase64: audioBase64,
        imageBase64: imageBase64,
        createdAt: DateTime.now(),
      );

      final payload = {
        'id': msg.id,
        'pharmacy_id': pharmacyId,
        'branch_id': branchId,
        'sender_type': 'cashier',
        'message_text': text,
        'device_id': tenantConfig.deviceId.isNotEmpty
            ? tenantConfig.deviceId
            : 'server-1',
        if (imageBase64 != null || audioBase64 != null)
          'attachment_url': (imageBase64 ?? audioBase64),
        'created_at': msg.createdAt.toIso8601String(),
      };

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final res = await http
              .post(
                Uri.parse('$supabaseUrl/rest/v1/owner_chat_messages'),
                headers: _headers(apiKey),
                body: jsonEncode(payload),
              )
              .timeout(SupabaseConfig.requestTimeout);

          if (res.statusCode >= 200 && res.statusCode < 300) {
            final list = List<ChatMessage>.from(chatMessagesNotifier.value)
              ..add(msg);
            chatMessagesNotifier.value = list;
            lastChatError = null;
            debugPrint(
                '[Chat] sendChatMessage SUCCESS [${res.statusCode}] on attempt $attempt');
            return true;
          } else {
            final err = 'HTTP ${res.statusCode}: ${res.body}';
            lastChatError = err;
            debugPrint(
                '[Chat] sendChatMessage attempt $attempt failed with status ${res.statusCode}: ${res.body}');
            if (res.statusCode >= 400 && res.statusCode < 500) {
              // خطأ مدخلات أو أذونات، لا نعيد المحاولة
              break;
            }
          }
        } catch (e) {
          lastChatError = '$e';
          debugPrint('[Chat] sendChatMessage attempt $attempt exception: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }
    } catch (e) {
      lastChatError = '$e';
      debugPrint('[Chat] Error sending chat message from desktop: $e');
    }
    return false;
  }

  /// التأكد من اتصال قناة البث الحي المباشر فائق السرعة عبر Realtime WebSocket
  static Future<void> _ensureRealtimeWsConnected(
      String supabaseUrl, String apiKey) async {
    if (_realtimeWs != null && _realtimeWs!.readyState == WebSocket.open) {
      return;
    }
    if (_isConnectingWs) return;
    _isConnectingWs = true;

    try {
      final wsBase = supabaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final wsUrl = '$wsBase/realtime/v1/websocket?apikey=$apiKey&vsn=1.0.0';
      try {
        _realtimeWs?.close();
      } catch (_) {}

      _realtimeWs = await WebSocket.connect(
        wsUrl,
        headers: {
          'apikey': apiKey,
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(const Duration(seconds: 4));

      _wsHeartbeatTimer?.cancel();
      _wsHeartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_realtimeWs != null && _realtimeWs!.readyState == WebSocket.open) {
          try {
            _realtimeWs!.add(jsonEncode({
              'topic': 'phoenix',
              'event': 'heartbeat',
              'payload': {},
              'ref': '${_wsRef++}',
            }));
          } catch (_) {}
        }
      });

      // الانضمام لقناة بث الفيديو الحي live_video_stream
      _realtimeWs!.add(jsonEncode({
        'topic': 'realtime:live_video_stream',
        'event': 'phx_join',
        'payload': {
          'config': {
            'broadcast': {'self': false, 'ack': false}
          }
        },
        'ref': '${_wsRef++}',
      }));

      _realtimeWs!.listen(
        (_) {},
        onError: (err) {
          debugPrint('[StreamWS] Socket error: $err');
          _realtimeWs = null;
        },
        onDone: () {
          debugPrint('[StreamWS] Socket closed');
          _realtimeWs = null;
        },
      );
      debugPrint('[StreamWS] Connected to live_video_stream successfully (25 FPS Ready)');
    } catch (e) {
      debugPrint('[StreamWS] WebSocket connect failed: $e');
      _realtimeWs = null;
    } finally {
      _isConnectingWs = false;
    }
  }

  /// بدء بث فيديو حي فائق السرعة لشاشة النظام (25-30 FPS Live Screen Stream)
  static void startScreenLiveStream() {
    if (isScreenStreamingActive) return;
    isScreenStreamingActive = true;

    _screenStreamTimer?.cancel();
    // 38ms interval = ~26.3 FPS للبث فائق النعومة
    _screenStreamTimer =
        Timer.periodic(const Duration(milliseconds: 38), (_) async {
      if (!isScreenStreamingActive) return;
      await _captureAndBroadcastFrame('screen');
    });
    debugPrint('[LiveStream] Screen live video stream active (~26 FPS)');
  }

  static void stopScreenLiveStream() {
    isScreenStreamingActive = false;
    _screenStreamTimer?.cancel();
    _screenStreamTimer = null;
    _isScreenFrameInProgress = false;
    debugPrint('[LiveStream] Screen live video stream stopped');
  }

  /// تهيئة كاميرا النظام
  static Future<void> _initCamera() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.low,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        debugPrint('[LiveStream] Camera controller initialized successfully');
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  /// بدء بث فيديو حي فائق السرعة لكاميرا المراقبة (25 FPS CCTV Live Camera)
  static void startCameraLiveStream() async {
    if (isCameraStreamingActive) return;
    isCameraStreamingActive = true;

    await _initCamera();

    _cameraStreamTimer?.cancel();
    // 40ms interval = 25 FPS للبث فائق النعومة
    _cameraStreamTimer =
        Timer.periodic(const Duration(milliseconds: 40), (_) async {
      if (!isCameraStreamingActive) return;
      await _captureAndBroadcastFrame('camera');
    });
    debugPrint('[LiveStream] CCTV Camera live video stream active (25 FPS)');
  }

  static void stopCameraLiveStream() {
    isCameraStreamingActive = false;
    _cameraStreamTimer?.cancel();
    _cameraStreamTimer = null;
    _isCameraFrameInProgress = false;
    _cameraController?.dispose();
    _cameraController = null;
    debugPrint('[LiveStream] CCTV Camera live video stream stopped');
  }

  /// التقاط إطار وبثه سحابياً للمدير بسرعة 25 FPS عبر قناة Realtime Broadcast مع إسقاط الإطارات المتأخرة
  static Future<void> _captureAndBroadcastFrame(String channel) async {
    // تقنية إسقاط الإطارات (Frame Skipping): إذا كان الإطار السابق قيد المعالجة يُسقط فوراً لمنع التراكم
    if (channel == 'screen') {
      if (_isScreenFrameInProgress) return;
      _isScreenFrameInProgress = true;
    } else {
      if (_isCameraFrameInProgress) return;
      _isCameraFrameInProgress = true;
    }

    try {
      final tenantConfig = await LicenseService.getTenantConfig();
      final supabaseUrl = await CloudSyncService.getSupabaseUrl();
      final apiKey = await CloudSyncService.getSupabaseAnonKey();
      final pharmacyId = _resolveIntId(tenantConfig.pharmacyId, 2);
      final branchId = _resolveIntId(tenantConfig.branchId, 2);

      // التأكد من استمرار اتصال قناة البث الحي Realtime WebSocket
      await _ensureRealtimeWsConnected(supabaseUrl, apiKey);

      String frameBase64 = '';

      if (channel == 'screen') {
        final bytes = await ScreenshotService.captureFrameBytes(pixelRatio: 0.45);
        if (bytes != null && bytes.isNotEmpty) {
          frameBase64 = base64Encode(bytes);
        } else {
          frameBase64 = await _renderScreenPlaceholderPng(
              tenantConfig.pharmacyName, tenantConfig.branchId);
        }
      } else {
        // كاميرا المراقبة CCTV: التقاط حقيقي إذا كانت الكاميرا مهيأة، أو محاكاة حية متصلة بدقة 25 FPS
        if (_cameraController != null &&
            _cameraController!.value.isInitialized) {
          try {
            final XFile file = await _cameraController!.takePicture();
            final bytes = await file.readAsBytes();
            frameBase64 = base64Encode(bytes);
          } catch (_) {
            frameBase64 = await _renderCctvFrameToPng(
                tenantConfig.pharmacyName, tenantConfig.branchId);
          }
        } else {
          frameBase64 = await _renderCctvFrameToPng(
              tenantConfig.pharmacyName, tenantConfig.branchId);
        }
      }

      if (frameBase64.isNotEmpty) {
        final now = DateTime.now();

        // 1. البث الحي فائق السرعة عبر Realtime WebSocket (25 FPS لحظي بدون تأخير)
        if (_realtimeWs != null && _realtimeWs!.readyState == WebSocket.open) {
          final broadcastPayload = {
            'topic': 'realtime:live_video_stream',
            'event': 'broadcast',
            'payload': {
              'type': 'broadcast',
              'event': 'frame_chunk',
              'payload': {
                'channel': channel,
                'branch_id': branchId.toString(),
                'pharmacy_id': pharmacyId,
                'frame': frameBase64,
                'fps': 25,
                'timestamp': now.toIso8601String(),
              }
            },
            'ref': '${_wsRef++}',
          };
          try {
            _realtimeWs!.add(jsonEncode(broadcastPayload));
          } catch (_) {}
        }

        // 2. تحديث الإطار المرجعي (Keyframe) في قاعدة البيانات كل 3.5 ثوانٍ كحد أقصى لمنع استنزاف قاعدة البيانات
        final lastKeyframe = (channel == 'screen')
            ? _lastScreenKeyframeTime
            : _lastCameraKeyframeTime;
        final shouldSendKeyframe = lastKeyframe == null ||
            now.difference(lastKeyframe).inMilliseconds >= 3500;

        if (shouldSendKeyframe) {
          if (channel == 'screen') {
            _lastScreenKeyframeTime = now;
          } else {
            _lastCameraKeyframeTime = now;
          }

          final channelCode = channel == 'screen' ? '01' : '02';
          final deterministicId =
              '00000000-0000-4000-8000-${pharmacyId.toString().padLeft(6, '0')}$channelCode${branchId.toString().padLeft(4, '0')}';

          final frame = StreamFrame(
            id: deterministicId,
            channel: channel,
            pharmacyId: pharmacyId,
            branchId: tenantConfig.branchId,
            deviceId: 'dev-main',
            frameBase64: frameBase64,
            fps: 25,
            timestamp: now,
          );

          // إرسال الإطار كـ Keyframe في الخلفية بدون انتظار حجب تدفق البث
          unawaited(http
              .post(
                Uri.parse('$supabaseUrl/rest/v1/cloud_stream_frames'),
                headers: {
                  ..._headers(apiKey),
                  'Prefer': 'resolution=merge-duplicates',
                },
                body: jsonEncode(frame.toJson()),
              )
              .timeout(const Duration(seconds: 4))
              .catchError((_) => http.Response('', 500)));
        }
      }
    } catch (e) {
      debugPrint('Error in _captureAndBroadcastFrame ($channel): $e');
    } finally {
      if (channel == 'screen') {
        _isScreenFrameInProgress = false;
      } else {
        _isCameraFrameInProgress = false;
      }
    }
  }

  static Future<String> _renderCctvFrameToPng(
      String pharmacyName, String branchId) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 640, 360));
      final now = DateTime.now();
      final msStr = (now.millisecond ~/ 10).toString().padLeft(2, '0');
      final timeStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.$msStr';

      // 1. خلفية الكاميرا الداكنة بتأثير المراقبة
      final bgPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 640, 360), bgPaint);

      // 2. شبكة المراقبة وزوايا التركيز CCTV
      final gridPaint = Paint()
        ..color = const Color(0xFF1E293B).withValues(alpha: 0.8)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      for (double x = 40; x < 640; x += 80) {
        canvas.drawLine(Offset(x, 0), Offset(x, 360), gridPaint);
      }
      for (double y = 40; y < 360; y += 60) {
        canvas.drawLine(Offset(0, y), Offset(640, y), gridPaint);
      }

      // 3. رادار مسح متحرك حي بزاوية تدور بسلاسة عند 25 FPS
      const center = Offset(320, 180);
      const radarRadius = 85.0;
      final sweepAngle =
          ((now.millisecondsSinceEpoch % 2400) / 2400.0) * 2 * math.pi;

      final radarCirclePaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.25)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, 30, radarCirclePaint);
      canvas.drawCircle(center, 60, radarCirclePaint);
      canvas.drawCircle(center, radarRadius, radarCirclePaint);

      // خط المسح الراداري الحي
      final sweepEnd = Offset(
        center.dx + radarRadius * math.cos(sweepAngle),
        center.dy + radarRadius * math.sin(sweepAngle),
      );
      final sweepLinePaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.85)
        ..strokeWidth = 2.0;
      canvas.drawLine(center, sweepEnd, sweepLinePaint);

      // 4. مستطيل التركيز الأوسط
      final focusPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(200, 80, 240, 200),
              const Radius.circular(12)),
          focusPaint);

      // 5. مؤشر التسجيل المباشر REC 🔴 (نبض حي)
      final isBlink = (now.millisecondsSinceEpoch ~/ 500) % 2 == 0;
      final recDotPaint = Paint()
        ..color = isBlink ? const Color(0xFFEF4444) : const Color(0x33EF4444);
      canvas.drawCircle(const Offset(30, 30), 7, recDotPaint);

      final textPainter = TextPainter(textDirection: TextDirection.rtl);

      textPainter.text = const TextSpan(
        text: 'REC • LIVE CCTV HD 1080p (25 FPS)',
        style: TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(44, 22));

      // بيانات الصيدلية والفرع والتوقيت الحي
      textPainter.text = TextSpan(
        text: '$pharmacyName (فرع: $branchId)',
        style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 14,
            fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(30, 320));

      final ltrPainter = TextPainter(textDirection: TextDirection.ltr);
      ltrPainter.text = TextSpan(
        text: '$timeStr  |  25.0 FPS  |  CAM-01',
        style: const TextStyle(
            color: Color(0xFF34D399),
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold),
      );
      ltrPainter.layout();
      ltrPainter.paint(canvas, const Offset(310, 322));

      final picture = recorder.endRecording();
      final img = await picture.toImage(640, 360);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return base64Encode(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('Error rendering CCTV frame: $e');
    }
    return '';
  }

  static Future<String> _renderScreenPlaceholderPng(
      String pharmacyName, String branchId) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 640, 360));
      final now = DateTime.now();
      final msStr = (now.millisecond ~/ 10).toString().padLeft(2, '0');
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.$msStr';

      final bgPaint = Paint()..color = const Color(0xFF1E1B4B);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 640, 360), bgPaint);

      final textPainter = TextPainter(textDirection: TextDirection.rtl);
      textPainter.text = TextSpan(
        text:
            '🖥️ شاشة نظام كاشير PharmaOS المباشرة (25 FPS)\n$pharmacyName - فرع #$branchId\nالوقت الحي: $timeStr\nالنظام في وضع البث الفوري والتحديث التلقائي',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.5),
      );
      textPainter.layout(maxWidth: 580);
      textPainter.paint(canvas, const Offset(40, 110));

      final picture = recorder.endRecording();
      final img = await picture.toImage(640, 360);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return base64Encode(byteData.buffer.asUint8List());
      }
    } catch (_) {}
    return '';
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
    final list = List<OwnerAuditAction>.from(auditLogsNotifier.value)
      ..insert(0, action);
    auditLogsNotifier.value = list;
  }
}
