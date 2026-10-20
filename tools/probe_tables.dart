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

  final possibleTables = [
    'pharmacies', 'branches', 'cloud_medicines', 'cloud_sales', 'cloud_sale_items',
    'cloud_purchases', 'cloud_purchase_items', 'cloud_sales_returns', 'cloud_returns',
    'cloud_day_closings', 'cloud_customers', 'cloud_suppliers', 'cloud_expenses',
    'cloud_batches', 'cloud_tele_consultations', 'cloud_backups', 'pending_backup_queue',
    'owner_chat_messages', 'cloud_stream_frames', 'remote_commands', 'owner_audit_actions'
  ];

  for (final t in possibleTables) {
    final res = await http.get(Uri.parse('$supabaseUrl/rest/v1/$t?limit=1'), headers: headers);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body);
      final cols = (list is List && list.isNotEmpty) ? list.first.keys.toList() : 'empty';
      print('EXISTS: $t -> $cols');
    } else {
      print('MISSING: $t (${res.statusCode})');
    }
  }
}
