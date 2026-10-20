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

  final chatPayload = {
    'id': 'a0000000-0000-4000-8000-000000000001',
    'pharmacy_id': 2,
    'branch_id': 2,
    'sender_type': 'owner',
    'sender_name': 'المدير العام',
    'sender_role': 'owner',
    'message_text': 'تجربة محادثة سريعة للمدير',
    'device_id': 'phone-app',
    'created_at': DateTime.now().toIso8601String(),
  };

  final res = await http.post(
    Uri.parse('$supabaseUrl/rest/v1/owner_chat_messages'),
    headers: headers,
    body: jsonEncode(chatPayload),
  );
  print('Chat insert status: ${res.statusCode}');
  print('Chat body: ${res.body}');
}
