import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  final desktopPath = p.join(
    Platform.environment['USERPROFILE'] ?? 'C:\\Users\\hp',
    'Desktop',
    'PharmaOS_Pharmacy_Ready',
  );

  print('Deploying to: $desktopPath');
  final destDir = Directory(desktopPath);
  if (await destDir.exists()) {
    await destDir.delete(recursive: true);
  }
  await destDir.create(recursive: true);

  final releaseDir = Directory(p.join(Directory.current.path, 'build', 'windows', 'x64', 'runner', 'Release'));
  if (!await releaseDir.exists()) {
    print('ERROR: Release folder does not exist at ${releaseDir.path}');
    return;
  }

  // Copy release contents
  await _copyDirectory(releaseDir, destDir);

  // Copy pre-seeded database
  final dbFile = File(p.join(
    Platform.environment['APPDATA'] ?? '',
    'com.example',
    'pharmaos',
    'pharmaos_secure.db',
  ));

  if (await dbFile.exists()) {
    final destDb = File(p.join(destDir.path, 'pharmaos_secure.db'));
    await dbFile.copy(destDb.path);
    print('Copied pre-seeded database (${await destDb.length()} bytes)');
  } else {
    print('WARNING: Database not found at ${dbFile.path}');
  }

  // Create One-Click Launcher batch file
  final batFile = File(p.join(destDir.path, 'تشغيل_نظام_الصيدلية.bat'));
  await batFile.writeAsString('''@echo off
chcp 65001 > nul
title PharmaOS - نظام إدارة الصيدلية
echo ===================================================
echo جاري إطلاق نظام PharmaOS المتطور للصيدليات...
echo ===================================================
cd /d "%~dp0"
start "" "%~dp0pharmaos.exe"
exit
''', mode: FileMode.write);

  // Create README / Instructions file
  final readmeFile = File(p.join(destDir.path, 'دليل_التشغيل_والبيانات.txt'));
  await readmeFile.writeAsString('''================================================================================
                    PharmaOS - نظام إدارة الصيدليات المتكامل
                    (نسخة التسليم الرسمية والجاهزة للعمل فوراً)
================================================================================

مرحباً بك في نظام PharmaOS المخصص لإدارة الصيدليات بالكامل أوفلاين دون الحاجة للإنترنت.

1. طريقة التشغيل:
   - اضغط نقراً مزدوجاً على الملف: "تشغيل_نظام_الصيدلية.bat" 
     أو مباشرة على "pharmaos.exe".

2. بيانات تسجيل الدخول الافتراضية (حساب المدير العام):
   - اسم المستخدم: admin
   - كلمة المرور: admin123
   - كما يمكنك استخدام بصمة اللابتوب (Windows Hello) بضغطة واحدة لتسجيل الدخول السريع.

3. محتويات قاعدة البيانات المرفقة والجاهزة:
   - أكثر من 33,500 صنف دوائي مسجل ومصنف بالكامل (بالاسم التجاري، العلمي، والسعر).
   - نظام الوحدات الذكي المحدث:
     * الإبر والفايل: بيع وشراء بـ (كرتون + باكت + حبة/أمبولة).
     * المحاليل والعلب والزجاج: بيع وشراء بـ (كرتون + علبة).
     * الفراشات والسرنجات: بيع وشراء بـ (كرتون + حبة).
     * الحبوب والأقراص: بيع وشراء بـ (كرتون + باكت + شريط + حبة).
   - الحسابات واليوميات والتقارير والشركات والموردين جاهزة للعمل مباشرة.

4. النقل لجهاز آخر:
   - يمكنك نسخ هذا المجلد بالكامل ("PharmaOS_Pharmacy_Ready") إلى فلاشة (USB)
     ولصقه على أي جهاز كمبيوتر أو لابتوب في الصيدلية وسيعمل مباشرة بكل بياناته.
================================================================================
''');

  print('Deployment complete successfully!');
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await for (final entity in source.list(recursive: false)) {
    if (entity is Directory) {
      final newDirectory = Directory(p.join(destination.path, p.basename(entity.path)));
      await newDirectory.create(recursive: true);
      await _copyDirectory(entity, newDirectory);
    } else if (entity is File) {
      await entity.copy(p.join(destination.path, p.basename(entity.path)));
    }
  }
}
