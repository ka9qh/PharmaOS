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

  final tables = ['owner_chat_messages', 'cloud_stream_frames', 'cloud_sales', 'cloud_purchases', 'cloud_tele_consultations', 'remote_commands'];
  for (final t in tables) {
    final res = await http.get(Uri.parse('$supabaseUrl/rest/v1/$t?limit=1'), headers: headers);
    print('$t: ${res.statusCode}');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body);
      if (list is List && list.isNotEmpty) {
        print('  Sample row: ${list.first.keys.toList()}');
      } else {
        print('  Empty list');
      }
    } else {
      print('  Error: ${res.body}');
    }
  }
}
