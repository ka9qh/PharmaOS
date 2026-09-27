// PharmaOS Supabase Verified Test Utility
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const supabaseUrl = 'https://bwgilcmzffcwdcxhfyfk.supabase.co';
  const apiKey = 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16';
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
