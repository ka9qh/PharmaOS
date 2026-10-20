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
    'Prefer': 'resolution=merge-duplicates,return=representation',
  };

  // Valid 1x1 transparent png base64
  const testPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

  final deterministicId = '00000000-0000-4000-8000-000002010002';

  final payload = {
    'id': deterministicId,
    'pharmacy_id': 2,
    'branch_id': 2,
    'stream_type': 'screen',
    'channel': 'screen',
    'frame_data': testPng,
    'frame_base64': testPng,
    'fps': 15,
    'device_id': 'dev-main',
    'created_at': DateTime.now().toIso8601String(),
    'timestamp': DateTime.now().toIso8601String(),
  };

  final res = await http.post(
    Uri.parse('$supabaseUrl/rest/v1/cloud_stream_frames'),
    headers: headers,
    body: jsonEncode(payload),
  );
  print('cloud_stream_frames upsert status: ${res.statusCode}');
  print('body: ${res.body}');
}
