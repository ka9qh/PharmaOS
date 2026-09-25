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

  // Test inserting a chat message
  final chatPayload = {
    'id': 'test-msg-1234',
    'pharmacy_id': 1,
    'branch_id': '1',
    'device_id': 'server-1',
    'sender_name': 'الصيدلي',
    'sender_role': 'pharmacist',
    'text': 'تجربة اتصال',
    'created_at': DateTime.now().toIso8601String(),
  };

  var res = await http.post(Uri.parse('$supabaseUrl/rest/v1/owner_chat_messages'), headers: headers, body: jsonEncode(chatPayload));
  print('Chat Message Insert: ${res.statusCode}');
  if (res.statusCode >= 400) {
    print('  ${res.body}');
  }

  // Test inserting a stream frame
  final framePayload = {
    'channel': 'screen',
    'pharmacy_id': 1,
    'branch_id': '1',
    'device_id': 'dev-main',
    'frame_base64': 'iVBORw0KGgo=',
    'fps': 15,
    'timestamp': DateTime.now().toIso8601String(),
  };

  res = await http.post(Uri.parse('$supabaseUrl/rest/v1/cloud_stream_frames'), headers: headers, body: jsonEncode(framePayload));
  print('Stream Frame Insert: ${res.statusCode}');
  if (res.statusCode >= 400) {
    print('  ${res.body}');
  }
}
