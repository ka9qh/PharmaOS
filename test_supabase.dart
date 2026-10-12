// PharmaOS Supabase Verified Test Utility
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
  };

  final res1 = await http.get(Uri.parse('$supabaseUrl/rest/v1/pharmacies?id=eq.2&select=id,name,is_active,paused_by_admin,subscription_type,subscription_end&limit=1'), headers: headers);
  print('Query with specific columns status: ${res1.statusCode} - body: ${res1.body}');

  final res2 = await http.get(Uri.parse('$supabaseUrl/rest/v1/pharmacies?id=eq.2&select=id,name,license_key,is_active&limit=1'), headers: headers);
  print('Query with basic columns status: ${res2.statusCode} - body: ${res2.body}');
}
