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

  final res = await http.get(Uri.parse('$supabaseUrl/rest/v1/pharmacies?select=*'), headers: headers);
  print('Supabase connected: ${res.statusCode}');
}
