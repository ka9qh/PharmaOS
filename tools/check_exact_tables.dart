import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const supabaseUrl = 'https://bwgilcmzffcwdcxhfyfk.supabase.co';
  const apiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3Z2lsY216ZmZjd2RjeGhmeWZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5MDMzMzEsImV4cCI6MjEwNDQ3OTMzMX0.ldSLO0S-OvUb1RR9ewMkM-COVvlon0-hl6tBh4VsjGA';

  final headers = {
    'apikey': apiKey,
    'Authorization': 'Bearer $apiKey',
    'Accept': 'application/openapi+json'
  };

  final res = await http.get(Uri.parse('$supabaseUrl/rest/v1/'), headers: headers);
  if (res.statusCode == 200) {
    final spec = jsonDecode(res.body);
    final definitions = spec['definitions'] as Map<String, dynamic>? ?? {};
    final paths = spec['paths'] as Map<String, dynamic>? ?? {};

    print('Available tables in Supabase:');
    for (final table in definitions.keys) {
      final properties = definitions[table]['properties'] as Map<String, dynamic>? ?? {};
      final required = definitions[table]['required'] as List<dynamic>? ?? [];
      print('=== TABLE: $table ===');
      print('  Required: $required');
      print('  Columns: ${properties.keys.toList()}');
    }
  } else {
    print('Failed: ${res.statusCode} ${res.body}');
  }
}
