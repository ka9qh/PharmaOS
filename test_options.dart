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

  final res = await http.get(Uri.parse('$supabaseUrl/rest/v1/cloud_stream_frames?limit=1'), headers: {
    ...headers,
    'Accept': 'application/openapi+json'
  });
  
  print(res.statusCode);
  if (res.statusCode == 200) {
    print(res.body.substring(0, 500)); // Print just the beginning to avoid huge output
  }
}
