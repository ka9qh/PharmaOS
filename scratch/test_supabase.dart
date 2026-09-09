import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://bwgilcmzffcwdcxhfyfk.supabase.co/rest/v1/pharmacies?select=*');
  final headers = {
    'apikey': 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16',
    'Authorization': 'Bearer sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16',
  };

  for (int i = 1; i <= 3; i++) {
    try {
      print('🔄 Attempt $i connecting to Supabase...');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
      print('✅ HTTP Status: ${response.statusCode}');
      print('📦 Body: ${response.body}');
      if (response.statusCode == 200) {
        print('🎉 Successfully connected to Supabase and verified pharmacies table!');
        return;
      }
    } catch (e) {
      print('⚠️ Attempt $i failed: $e');
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
