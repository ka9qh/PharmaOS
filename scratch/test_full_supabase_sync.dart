import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final supabaseUrl = 'https://bwgilcmzffcwdcxhfyfk.supabase.co';
  final apiKey = 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16';
  final headers = {
    'apikey': apiKey,
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation,resolution=merge-duplicates',
  };

  print('🚀 Starting Supabase Full Schema & Sync Verification...');

  // 1. مزامنة الصيدلية في pharmacies
  final pharmacy = {
    'id': 1,
    'name': 'صيدلية الأمل النموذجية - المركز الرئيسي',
    'license_key': 'PHARMA-OS-DEMO-2026',
    'phone': '777000111',
    'address': 'صنعاء - شارع الستين',
    'is_active': true,
    'updated_at': DateTime.now().toIso8601String(),
  };

  try {
    final res = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/pharmacies'),
      headers: headers,
      body: jsonEncode(pharmacy),
    );
    print('1️⃣ Pharmacy Sync: Status ${res.statusCode} -> ${res.body}');
  } catch (e) {
    print('⚠️ Pharmacy Sync error: $e');
  }

  // 2. مزامنة الفرع في branches
  final branch = {
    'id': 1,
    'pharmacy_id': 1,
    'name': 'الفرع الرئيسي - كاشير 1',
    'device_fingerprint': 'POS-WIN-DEV-001',
    'is_active': true,
  };

  try {
    final res = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/branches'),
      headers: headers,
      body: jsonEncode(branch),
    );
    print('2️⃣ Branch Sync: Status ${res.statusCode} -> ${res.body}');
  } catch (e) {
    print('⚠️ Branch Sync error: $e');
  }

  // 3. مزامنة عينة أدوية مع باركود المصنع في cloud_medicines
  final sampleMeds = [
    {
      'pharmacy_id': 1,
      'local_id': 1,
      'name_ar': 'بارامول 500 ملجم أقراص',
      'name_en': 'Paramol 500mg Tablets',
      'name_scientific': 'Paracetamol 500mg',
      'barcode': '6281086001019',
      'selling_price': 500.0,
      'purchase_price': 350.0,
      'reorder_level': 10,
    },
    {
      'pharmacy_id': 1,
      'local_id': 2,
      'name_ar': 'أوجمنتين 1 جم أقراص',
      'name_en': 'Augmentin 1g Tablets',
      'name_scientific': 'Amoxicillin + Clavulanic Acid 1g',
      'barcode': '5000158068698',
      'selling_price': 3200.0,
      'purchase_price': 2700.0,
      'reorder_level': 5,
    },
    {
      'pharmacy_id': 1,
      'local_id': 3,
      'name_ar': 'باندول إكسترا أقراص',
      'name_en': 'Panadol Extra Tablets',
      'name_scientific': 'Paracetamol + Caffeine',
      'barcode': '5000347060144',
      'selling_price': 800.0,
      'purchase_price': 600.0,
      'reorder_level': 15,
    },
  ];

  try {
    final res = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/cloud_medicines'),
      headers: headers,
      body: jsonEncode(sampleMeds),
    );
    print('3️⃣ Cloud Medicines Sync: Status ${res.statusCode} -> ${res.body}');
  } catch (e) {
    print('⚠️ Cloud Medicines Sync error: $e');
  }

  // 4. مزامنة فواتير مبيعات سحابية في cloud_sales
  final sampleSale = {
    'pharmacy_id': 1,
    'branch_id': 1,
    'local_sale_id': 101,
    'invoice_number': 'INV-2026-0001',
    'total_amount': 3700.0,
    'discount_amount': 0.0,
    'net_amount': 3700.0,
    'paid_amount': 3700.0,
    'payment_method': 'نقدي',
    'cashier_name': 'د. الصيدلي المناوب',
    'created_at': DateTime.now().toIso8601String(),
  };

  try {
    final res = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/cloud_sales'),
      headers: headers,
      body: jsonEncode(sampleSale),
    );
    print('4️⃣ Cloud Sales Sync: Status ${res.statusCode} -> ${res.body}');
  } catch (e) {
    print('⚠️ Cloud Sales Sync error: $e');
  }

  // 5. مزامنة إغلاق اليومية في cloud_day_closings
  final sampleClosing = {
    'pharmacy_id': 1,
    'branch_id': 1,
    'date': DateTime.now().toIso8601String().substring(0, 10),
    'period_start': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
    'total_sales': 150000.0,
    'total_returns': 2000.0,
    'total_expenses': 5000.0,
    'cost_of_goods_sold': 105000.0,
    'net_profit': 38000.0,
    'cash_in_drawer': 143000.0,
  };

  try {
    final res = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/cloud_day_closings'),
      headers: headers,
      body: jsonEncode(sampleClosing),
    );
    print('5️⃣ Cloud Day Closings Sync: Status ${res.statusCode} -> ${res.body}');
  } catch (e) {
    print('⚠️ Cloud Day Closings Sync error: $e');
  }

  // 6. مزامنة استشارة روشتة في cloud_tele_consultations
  final sampleConsultation = {
    'pharmacy_id': 1,
    'branch_id': 1,
    'pharmacist_name': 'د. أحمد (الصيدلي)',
    'title': 'استشارة لصرف روشتة أطفال',
    'patient_name': 'طفل 5 سنوات',
    'notes': 'الرجاء تأكيد جرعة الشراب للصنف الثاني',
    'status': 'pending',
    'urgency': 'urgent',
    'created_at': DateTime.now().toIso8601String(),
  };

  try {
    final res = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/cloud_tele_consultations'),
      headers: headers,
      body: jsonEncode(sampleConsultation),
    );
    print('6️⃣ Cloud Tele Consultations Sync: Status ${res.statusCode} -> ${res.body}');
  } catch (e) {
    print('⚠️ Cloud Tele Consultations Sync error: $e');
  }

  print('🏁 Verification complete!');
}
