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

  final tables = ['remote_commands', 'owner_chat_messages', 'cloud_stream_frames', 'owner_audit_actions', 'pharmacies', 'branches'];

  for (var table in tables) {
    final res = await http.get(Uri.parse('$supabaseUrl/rest/v1/$table?limit=1'), headers: headers);
    print('Table $table: ${res.statusCode}');
    if (res.statusCode >= 400) {
      print('  Response: ${res.body}');
    }
  }
}
