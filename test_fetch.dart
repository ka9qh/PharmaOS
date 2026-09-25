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

  var res = await http.get(Uri.parse('$supabaseUrl/rest/v1/cloud_stream_frames?limit=1'), headers: headers);
  print(res.body);

  res = await http.get(Uri.parse('$supabaseUrl/rest/v1/owner_chat_messages?limit=1'), headers: headers);
  print(res.body);
}
