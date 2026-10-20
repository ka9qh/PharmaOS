import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const supabaseUrl = 'https://bwgilcmzffcwdcxhfyfk.supabase.co';
  const apiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3Z2lsY216ZmZjd2RjeGhmeWZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5MDMzMzEsImV4cCI6MjEwNDQ3OTMzMX0.ldSLO0S-OvUb1RR9ewMkM-COVvlon0-hl6tBh4VsjGA';

  final headers = {
    'apikey': apiKey,
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  // 1. Insert a test sale
  final salePayload = {
    'pharmacy_id': 2,
    'branch_id': 2,
    'local_sale_id': 99991,
    'invoice_number': 'INV-TEST-001',
    'total_amount': 2500.0,
    'discount_amount': 100.0,
    'net_amount': 2400.0,
    'paid_amount': 2400.0,
    'payment_method': 'نقدي',
    'cashier_name': 'كاشير #1',
    'customer_name': 'عميل نقدي',
    'created_at': DateTime.now().toIso8601String(),
  };

  final sRes = await http.post(
    Uri.parse('$supabaseUrl/rest/v1/cloud_sales'),
    headers: headers,
    body: jsonEncode(salePayload),
  );
  print('Sale insert status: ${sRes.statusCode}');
  print('Sale body: ${sRes.body}');

  if (sRes.statusCode == 201) {
    final sData = jsonDecode(sRes.body);
    final saleId = sData[0]['id'];
    print('Inserted sale ID: $saleId');

    // 2. Insert items for this sale
    final itemsPayload = [
      {
        'pharmacy_id': 2,
        'sale_id': saleId,
        'medicine_name': 'بانادول اكسترا 500 ملجم',
        'quantity': 2,
        'unit_price': 600.0,
        'total_price': 1200.0,
        'unit_name': 'باكت',
      },
      {
        'pharmacy_id': 2,
        'sale_id': saleId,
        'medicine_name': 'أوجمنتين 1 جم أقراص',
        'quantity': 1,
        'unit_price': 1200.0,
        'total_price': 1200.0,
        'unit_name': 'باكت',
      }
    ];

    final iRes = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/cloud_sale_items'),
      headers: headers,
      body: jsonEncode(itemsPayload),
    );
    print('Items insert status: ${iRes.statusCode}');
    print('Items body: ${iRes.body}');

    // 3. Query items back
    final qRes = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/cloud_sale_items?sale_id=eq.$saleId'),
      headers: headers,
    );
    print('Query items: ${qRes.statusCode} -> ${qRes.body}');
  }
}
