import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://bwgilcmzffcwdcxhfyfk.supabase.co/rest/v1/cloud_medicines?limit=1';
  const key = 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16';
  
  print('Pinging Supabase...');
  try {
    final response = await http.get(Uri.parse(url), headers: {
      'apikey': key,
      'Authorization': 'Bearer $key',
    });
    
    print('Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      print('Connection successful! Data received:');
      print(response.body);
    } else {
      print('Error: ${response.body}');
    }
  } catch (e) {
    print('Exception caught: $e');
  }
}
