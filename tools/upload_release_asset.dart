// سكريبت رفع حزمة التحديث التلقائي إلى GitHub Releases مباشرة عبر GitHub REST API
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final token = Platform.environment['GITHUB_TOKEN'] ?? (args.isNotEmpty ? args[0] : '');
  const owner = 'ka9qh';
  const repo = 'PharmaOS';
  const tag = 'v1.0.2';
  const releaseName = 'PharmaOS Release v1.0.2';
  const body = 'تحديث شامل يتضمن:\n• نظام التحديثات التلقائية عن بُعد (OTA)\n• هيكل التراخيص وتعدد الصيدليات والفروع (Multi-Tenancy)\n• تقفيل الوردية وإيصال Z-Report والعد الفعلي للصندوق\n• لوحة الأرباح والخسائر المتقدمة (P&L Analytics)';

  print('🚀 Connecting to GitHub API to create/update release $tag...');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'PharmaOS-Release-Tool',
  };

  // 1. التحقق من وجود Release سابق أو إنشاء جديد
  int? releaseId;
  String? uploadUrlTemplate;

  final getReleaseRes = await http.get(
    Uri.parse('https://api.github.com/repos/$owner/$repo/releases/tags/$tag'),
    headers: headers,
  );

  if (getReleaseRes.statusCode == 200) {
    final data = jsonDecode(getReleaseRes.body);
    releaseId = data['id'];
    uploadUrlTemplate = data['upload_url'];
    print('ℹ️ Found existing release ID: $releaseId');
  } else {
    // إنشاء Release جديد
    final createRes = await http.post(
      Uri.parse('https://api.github.com/repos/$owner/$repo/releases'),
      headers: headers,
      body: jsonEncode({
        'tag_name': tag,
        'target_commitish': 'main',
        'name': releaseName,
        'body': body,
        'draft': false,
        'prerelease': false,
      }),
    );

    if (createRes.statusCode == 201) {
      final data = jsonDecode(createRes.body);
      releaseId = data['id'];
      uploadUrlTemplate = data['upload_url'];
      print('✅ Created new GitHub Release with ID: $releaseId');
    } else {
      print('❌ Failed to create release: ${createRes.statusCode} - ${createRes.body}');
      return;
    }
  }

  // 2. رفع الملفات المرفقة (pharmaos_update_v1.0.2.zip و version.json)
  final zipFile = File(p.join(Directory.current.path, 'build', 'github_releases', 'pharmaos_update_v1.0.2.zip'));
  final manifestFile = File(p.join(Directory.current.path, 'build', 'github_releases', 'version.json'));

  if (uploadUrlTemplate != null) {
    final cleanUploadUrl = uploadUrlTemplate.split('{')[0];

    // رفع ملف version.json
    if (await manifestFile.exists()) {
      print('📤 Uploading version.json to release assets...');
      final bytes = await manifestFile.readAsBytes();
      final res = await http.post(
        Uri.parse('$cleanUploadUrl?name=version.json'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
          'Content-Length': bytes.length.toString(),
        },
        body: bytes,
      );
      print('Result version.json: ${res.statusCode}');
    }

    // رفع ملف الحزمة المضغوطة .zip
    if (await zipFile.exists()) {
      print('📤 Uploading pharmaos_update_v1.0.2.zip (${(zipFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB)...');
      final zipBytes = await zipFile.readAsBytes();
      final res = await http.post(
        Uri.parse('$cleanUploadUrl?name=pharmaos_update_v1.0.2.zip'),
        headers: {
          ...headers,
          'Content-Type': 'application/zip',
          'Content-Length': zipBytes.length.toString(),
        },
        body: zipBytes,
      );
      print('Result zip upload: ${res.statusCode}');
      if (res.statusCode == 201) {
        print('🎉 Successfully uploaded update package to GitHub Release!');
      }
    }
  }

  print('\n🎯 GitHub Release is now LIVE at: https://github.com/$owner/$repo/releases/tag/$tag');
}
