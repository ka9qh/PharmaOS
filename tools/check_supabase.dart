import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://bwgilcmzffcwdcxhfyfk.supabase.co/rest/v1/cloud_medicines?limit=1';
  const key =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3Z2lsY216ZmZjd2RjeGhmeWZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5MDMzMzEsImV4cCI6MjEwNDQ3OTMzMX0.ldSLO0S-OvUb1RR9ewMkM-COVvlon0-hl6tBh4VsjGA';
  
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
