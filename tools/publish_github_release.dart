// سكريبت أتمتة بناء وإطلاق التحديثات وتوليد حزم GitHub Releases - PharmaOS Release Publisher
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  print('===========================================================');
  print('🚀 PharmaOS Automated Release & GitHub Publisher Tool');
  print('===========================================================');

  final version = args.isNotEmpty ? args[0] : '1.0.2';
  final buildNumber = args.length > 1 ? int.tryParse(args[1]) ?? 2 : 2;
  final changelog = args.length > 2
      ? args.sublist(2).join(' ')
      : '• إضافة نظام التحديثات التلقائية عن بعد (OTA)\n• إضافة هيكل التراخيص وتعدد الصيدليات والفروع (Multi-Tenant)\n• تحسينات شاملة في دقة تسعير الوحدات والمطابقة المالية';

  print('📦 Target Version: v$version (Build $buildNumber)');
  print('📝 Changelog:\n$changelog\n');

  // 1. بناء نسخة الويندوز
  print('🔨 Building Windows Release binary...');
  final buildResult = await Process.run('flutter', ['build', 'windows', '--release'], runInShell: true);
  if (buildResult.exitCode != 0) {
    print('❌ Build Failed: ${buildResult.stderr}');
    return;
  }
  print('✅ Windows Release built successfully.');

  // 2. مزامنة مجلد سطح المكتب
  print('📂 Syncing Desktop PharmaOS_Release folder...');
  final syncResult = await Process.run('dart', ['tools/update_pharmaos_release.dart'], runInShell: true);
  print(syncResult.stdout);

  // 3. ضغط حزمة التحديث للعملاء
  final releaseSourceDir = Directory(p.join(Directory.current.path, 'build', 'windows', 'x64', 'runner', 'Release'));
  final releaseArtifactsDir = Directory(p.join(Directory.current.path, 'build', 'github_releases'));
  if (!await releaseArtifactsDir.exists()) {
    await releaseArtifactsDir.create(recursive: true);
  }

  final zipFile = File(p.join(releaseArtifactsDir.path, 'pharmaos_update_v$version.zip'));
  if (await zipFile.exists()) await zipFile.delete();

  print('📦 Compressing update package to: ${zipFile.path}...');
  final compressResult = await Process.run('powershell', [
    '-ExecutionPolicy',
    'Bypass',
    '-NoProfile',
    '-Command',
    'Compress-Archive -Path "${releaseSourceDir.path}\\*" -DestinationPath "${zipFile.path}" -Force',
  ]);
  if (compressResult.exitCode != 0) {
    print('❌ Compression Failed: ${compressResult.stderr}');
    return;
  }

  if (!await zipFile.exists()) {
    print('❌ Compression Failed: Output zip file not found.');
    return;
  }

  // 4. حساب SHA-256 Hash
  final bytes = await zipFile.readAsBytes();
  final hash = sha256.convert(bytes).toString();
  print('🔒 Package SHA-256: $hash');

  // 5. إنشاء وتحديث ملف version.json
  final versionManifest = {
    'latest_version': version,
    'build_number': buildNumber,
    'release_date': DateTime.now().toIso8601String().substring(0, 10),
    'download_url': 'https://github.com/ka9qh/PharmaOS/releases/download/v$version/pharmaos_update_v$version.zip',
    'changelog_ar': changelog,
    'sha256': hash,
    'package_size_bytes': bytes.length,
    'is_mandatory': false,
  };

  final manifestFile = File(p.join(releaseArtifactsDir.path, 'version.json'));
  final jsonString = const JsonEncoder.withIndent('  ').convert(versionManifest);
  await manifestFile.writeAsString(jsonString);
  print('📄 Generated version.json successfully at: ${manifestFile.path}');

  // نسخ version.json إلى مجلد releases/ الرئيسي ليكون قابلاً للقراءة فوراً من GitHub
  final rootReleasesDir = Directory(p.join(Directory.current.path, 'releases'));
  if (!await rootReleasesDir.exists()) {
    await rootReleasesDir.create(recursive: true);
  }
  final rootManifestFile = File(p.join(rootReleasesDir.path, 'version.json'));
  await rootManifestFile.writeAsString(jsonString);
  print('🌐 Synced version.json to repository releases folder: ${rootManifestFile.path}');

  print('\n🎯 RELEASE PACKAGE READY FOR DEPLOYMENT!');
  print('1. Zip Package: ${zipFile.path} (${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB)');
  print('2. Manifest File: ${manifestFile.path}');
}
