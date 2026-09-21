import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://bwgilcmzffcwdcxhfyfk.supabase.co/rest/v1/remote_commands?limit=1';
  final res = await http.get(Uri.parse(url), headers: {'apikey': 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16', 'Authorization': 'Bearer sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16'});
  print('Status remote_commands: ${res.statusCode}');
  print('Body remote_commands: ${res.body}');

  final tables = ['cloud_medicines', 'cloud_sales', 'cloud_day_closings', 'cloud_tele_consultations', 'cloud_stream_frames', 'owner_chat_messages', 'cloud_purchases', 'cloud_backups'];
  for (var t in tables) {
    final tUrl = 'https://bwgilcmzffcwdcxhfyfk.supabase.co/rest/v1/$t?limit=1';
    final tRes = await http.get(Uri.parse(tUrl), headers: {'apikey': 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16', 'Authorization': 'Bearer sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16'});
    print('Status $t: ${tRes.statusCode}');
  }
}
