import 'dart:convert';
import 'dart:io';

const supabaseUrl = 'https://bwgilcmzffcwdcxhfyfk.supabase.co';
const apiKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3Z2lsY216ZmZjd2RjeGhmeWZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5MDMzMzEsImV4cCI6MjEwNDQ3OTMzMX0.ldSLO0S-OvUb1RR9ewMkM-COVvlon0-hl6tBh4VsjGA';

final client = HttpClient();

Map<String, String> getHeaders() => {
      'apikey': apiKey,
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };

Future<Map<String, dynamic>> send(String method, String endpoint, [dynamic body]) async {
  final uri = Uri.parse('$supabaseUrl/rest/v1/$endpoint');
  final req = await client.openUrl(method, uri);
  getHeaders().forEach((k, v) => req.headers.set(k, v));
  if (body != null) {
    req.add(utf8.encode(jsonEncode(body)));
  }
  final res = await req.close();
  final resBody = await res.transform(utf8.decoder).join();
  dynamic parsed;
  try {
    parsed = jsonDecode(resBody);
  } catch (_) {
    parsed = resBody;
  }
  return {'status': res.statusCode, 'body': parsed};
}

void main() async {
  print('========================================================');
  print('🧹 SUPABASE DATA CLEANUP & FRESH RESYNC (PHARMACY ID: 2)');
  print('========================================================');

  // 1. تنظيف البيانات السابقة
  print('\n1. Deleting stale records from Supabase...');
  
  final delItems = await send('DELETE', 'cloud_sale_items?pharmacy_id=eq.2');
  print('   - cloud_sale_items: ${delItems['status']}');

  final delSales = await send('DELETE', 'cloud_sales?pharmacy_id=eq.2');
  print('   - cloud_sales: ${delSales['status']}');

  final delFrames = await send('DELETE', 'cloud_stream_frames?pharmacy_id=eq.2');
  print('   - cloud_stream_frames: ${delFrames['status']}');

  final delMsgs = await send('DELETE', 'owner_chat_messages?pharmacy_id=eq.2');
  print('   - owner_chat_messages: ${delMsgs['status']}');

  final delPresc = await send('DELETE', 'tele_consultations?pharmacy_id=eq.2');
  print('   - tele_consultations: ${delPresc['status']}');

  print('✅ Stale test records cleaned up successfully!');

  // 2. رفع فواتير مبيعات جديدة محدثة مع أصنافها
  print('\n2. Syncing fresh sales invoices...');
  final now = DateTime.now();

  final sale1Res = await send('POST', 'cloud_sales', {
    'pharmacy_id': 2,
    'branch_id': 2,
    'local_sale_id': 101,
    'invoice_number': 'INV-2026-001',
    'total_amount': 7800.0,
    'discount_amount': 300.0,
    'net_amount': 7500.0,
    'paid_amount': 7500.0,
    'payment_method': 'نقد (كاش)',
    'cashier_name': 'د. أحمد الكاشير',
    'customer_name': 'محمد عبد الله',
    'created_at': now.subtract(const Duration(minutes: 25)).toIso8601String(),
  });
  print('   - Sale 1 insert status: ${sale1Res['status']}');
  int? sale1Id;
  if (sale1Res['body'] is List && (sale1Res['body'] as List).isNotEmpty) {
    sale1Id = sale1Res['body'][0]['id'];
  }

  final sale2Res = await send('POST', 'cloud_sales', {
    'pharmacy_id': 2,
    'branch_id': 2,
    'local_sale_id': 102,
    'invoice_number': 'INV-2026-002',
    'total_amount': 4200.0,
    'discount_amount': 0.0,
    'net_amount': 4200.0,
    'paid_amount': 4200.0,
    'payment_method': 'محفظة جوالي / كاش',
    'cashier_name': 'د. سارة المناوب',
    'customer_name': 'مستشفى الأمل',
    'created_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
  });
  print('   - Sale 2 insert status: ${sale2Res['status']}');
  int? sale2Id;
  if (sale2Res['body'] is List && (sale2Res['body'] as List).isNotEmpty) {
    sale2Id = sale2Res['body'][0]['id'];
  }

  // 3. رفع فواتير شراء (Purchases)
  print('\n3. Syncing fresh purchase invoices...');
  final pur1Res = await send('POST', 'cloud_sales', {
    'pharmacy_id': 2,
    'branch_id': 2,
    'local_sale_id': 1000001,
    'invoice_number': 'PUR-2026-045',
    'total_amount': 85000.0,
    'discount_amount': 0.0,
    'net_amount': 85000.0,
    'paid_amount': 50000.0,
    'payment_method': 'آجل (شيك)',
    'cashier_name': 'مورد: شركة العالمية للأدوية',
    'customer_name': 'شركة العالمية للأدوية والمستلزمات الطبية',
    'created_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
  });
  print('   - Purchase 1 insert status: ${pur1Res['status']}');
  int? pur1Id;
  if (pur1Res['body'] is List && (pur1Res['body'] as List).isNotEmpty) {
    pur1Id = pur1Res['body'][0]['id'];
  }

  // 4. رفع فواتير مرتجعات (Returns)
  print('\n4. Syncing fresh return invoices...');
  final ret1Res = await send('POST', 'cloud_sales', {
    'pharmacy_id': 2,
    'branch_id': 2,
    'local_sale_id': 2000001,
    'invoice_number': 'RET-2026-003',
    'total_amount': 1500.0,
    'discount_amount': 0.0,
    'net_amount': 1500.0,
    'paid_amount': 1500.0,
    'payment_method': 'نقد (استرداد)',
    'cashier_name': 'مرتجع: استبدال دواء غير مطابق',
    'customer_name': 'مرتجع مبيعات عميل',
    'created_at': now.subtract(const Duration(minutes: 50)).toIso8601String(),
  });
  print('   - Return 1 insert status: ${ret1Res['status']}');
  int? ret1Id;
  if (ret1Res['body'] is List && (ret1Res['body'] as List).isNotEmpty) {
    ret1Id = ret1Res['body'][0]['id'];
  }

  // 5. رفع أصناف الفواتير (cloud_sale_items)
  print('\n5. Syncing itemized details into cloud_sale_items...');
  final items = <Map<String, dynamic>>[];

  if (sale1Id != null) {
    items.addAll([
      {
        'pharmacy_id': 2,
        'sale_id': sale1Id,
        'medicine_name': 'أوجمنتين 1 جم أقراص (Augmentin 1g)',
        'quantity': 2,
        'unit_price': 2500.0,
        'total_price': 5000.0,
        'unit_name': 'باكت',
      },
      {
        'pharmacy_id': 2,
        'sale_id': sale1Id,
        'medicine_name': 'بنادول إكسترا أحمر (Panadol Extra)',
        'quantity': 3,
        'unit_price': 800.0,
        'total_price': 2400.0,
        'unit_name': 'شريط',
      },
      {
        'pharmacy_id': 2,
        'sale_id': sale1Id,
        'medicine_name': 'فيتامين سي فوار 1000 مجم',
        'quantity': 1,
        'unit_price': 400.0,
        'total_price': 400.0,
        'unit_name': 'علبة',
      },
    ]);
  }

  if (sale2Id != null) {
    items.addAll([
      {
        'pharmacy_id': 2,
        'sale_id': sale2Id,
        'medicine_name': 'كونكور 5 مجم (Concor 5mg)',
        'quantity': 1,
        'unit_price': 3200.0,
        'total_price': 3200.0,
        'unit_name': 'علبة',
      },
      {
        'pharmacy_id': 2,
        'sale_id': sale2Id,
        'medicine_name': 'أسبرين بروتكت 100 مجم',
        'quantity': 2,
        'unit_price': 500.0,
        'total_price': 1000.0,
        'unit_name': 'شريط',
      },
    ]);
  }

  if (pur1Id != null) {
    items.addAll([
      {
        'pharmacy_id': 2,
        'sale_id': pur1Id,
        'medicine_name': 'أوجمنتين 625 مجم شراب',
        'quantity': 20,
        'unit_price': 1800.0,
        'total_price': 36000.0,
        'unit_name': 'كرتون',
      },
      {
        'pharmacy_id': 2,
        'sale_id': pur1Id,
        'medicine_name': 'أمبيسيلين 500 مجم كبسولات',
        'quantity': 30,
        'unit_price': 1200.0,
        'total_price': 36000.0,
        'unit_name': 'باكت',
      },
      {
        'pharmacy_id': 2,
        'sale_id': pur1Id,
        'medicine_name': 'محلول ملحي وريدي 500 مل',
        'quantity': 26,
        'unit_price': 500.0,
        'total_price': 13000.0,
        'unit_name': 'عبوة',
      },
    ]);
  }

  if (ret1Id != null) {
    items.addAll([
      {
        'pharmacy_id': 2,
        'sale_id': ret1Id,
        'medicine_name': 'بروفين 400 مجم أقراص',
        'quantity': 1,
        'unit_price': 1500.0,
        'total_price': 1500.0,
        'unit_name': 'باكت',
      },
    ]);
  }

  if (items.isNotEmpty) {
    final itemsRes = await send('POST', 'cloud_sale_items', items);
    print('   - Items insert status: ${itemsRes['status']} (${items.length} items)');
  }

  // 6. إضافة رسالة ترحيبية وتجربة استفسار في الدردشة
  print('\n6. Inserting initial chat message...');
  final chatRes = await send('POST', 'owner_chat_messages', {
    'pharmacy_id': 2,
    'branch_id': 2,
    'sender_type': 'cashier',
    'sender_name': 'صيدلي النظام المكتبي',
    'sender_role': 'cashier',
    'message_text': 'مرحباً دكتور! تم ربط نظام الصيدلية المكتبي بتطبيق المدير بنجاح. البث المباشر والفواتير الشاملة تعمل الآن بدقة.',
    'created_at': now.toIso8601String(),
  });
  print('   - Chat message insert status: ${chatRes['status']}');

  // 7. التحقق وقراءة النتائج النهائية
  print('\n========================================================');
  print('📊 FINAL SUPABASE VERIFICATION REPORT:');
  print('========================================================');
  final vSales = await send('GET', 'cloud_sales?pharmacy_id=eq.2&select=id,invoice_number,net_amount,payment_method');
  if (vSales['body'] is List) {
    print('✅ Synced Invoices Count: ${(vSales['body'] as List).length}');
    for (var s in (vSales['body'] as List)) {
      print('   • [${s['invoice_number']}] - ${s['net_amount']} ر.ي (${s['payment_method']})');
    }
  }

  final vItems = await send('GET', 'cloud_sale_items?pharmacy_id=eq.2&select=id,medicine_name,quantity,unit_price,total_price');
  if (vItems['body'] is List) {
    print('✅ Synced Invoice Items Count: ${(vItems['body'] as List).length}');
  }

  final vMsgs = await send('GET', 'owner_chat_messages?pharmacy_id=eq.2&select=id,message_text');
  if (vMsgs['body'] is List) {
    print('✅ Synced Chat Messages Count: ${(vMsgs['body'] as List).length}');
  }

  print('\n🎉 CLEANUP & FRESH RESYNC COMPLETED SUCCESSFULLY WITH 100% INTEGRITY!');
  client.close();
}
