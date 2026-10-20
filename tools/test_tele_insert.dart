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

  final payload = {
    'pharmacy_id': 2,
    'branch_id': '2',
    'pharmacist_name': 'د. أحمد',
    'title': 'استشارة فحص روشتة',
    'patient_name': 'محمد علي',
    'notes': 'تحتاج مراجعة الجرعة',
    'status': 'pending',
    'urgency': 'normal',
    'created_at': DateTime.now().toIso8601String(),
  };

  final res = await http.post(
    Uri.parse('$supabaseUrl/rest/v1/cloud_tele_consultations'),
    headers: headers,
    body: jsonEncode(payload),
  );
  print('Tele consultation insert status: ${res.statusCode}');
  print('body: ${res.body}');
}
