// خدمة التقاط وتصوير الشاشة وحفظها - PharmaOS
// تتيح تصوير أي واجهة في النظام وحفظ الصورة مباشرة على سطح المكتب
// عبر زر عائم أو اختصار لوحة المفاتيح (F9 أو Ctrl+Shift+S) مع إمكانية إخفائه فورياً من الإعدادات.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/app_router.dart';

class ScreenshotService {
  static final GlobalKey globalBoundaryKey = GlobalKey();
  static const String _showFloatingButtonKey = 'show_screenshot_floating_btn_v1';
  static final ValueNotifier<bool> floatingButtonNotifier = ValueNotifier<bool>(true);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_showFloatingButtonKey) ?? true;
    floatingButtonNotifier.value = enabled;
  }

  static Future<bool> isFloatingButtonEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showFloatingButtonKey) ?? true;
  }

  static Future<void> setFloatingButtonEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showFloatingButtonKey, enabled);
    floatingButtonNotifier.value = enabled;
  }

  // تنفيذ التقاط الشاشة وحفظها
  static Future<File?> captureAndSave([BuildContext? context]) async {
    try {
      final boundary = globalBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('RepaintBoundary context not ready for screenshot');
        return null;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final desktopPath = Platform.isWindows
          ? p.join(Platform.environment['USERPROFILE'] ?? '', 'Desktop', 'PharmaOS_Screenshots')
          : Directory.current.path;

      final folder = Directory(desktopPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final now = DateTime.now();
      final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
      final fileName = 'PharmaOS_Capture_$timestamp.png';
      final file = File(p.join(folder.path, fileName));
      await file.writeAsBytes(pngBytes);

      final targetContext = context ?? AppRouter.rootNavigatorKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        _showSuccessDialog(targetContext, file);
      }

      return file;
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
      return null;
    }
  }

  static void _showSuccessDialog(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.teal),
              SizedBox(width: 8),
              Text('تم التقاط الشاشة بنجاح 📸'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تم حفظ لقطة الشاشة في مجلد سطح المكتب:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(file.path, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('فتح مجلد الصور'),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                Navigator.pop(ctx);
                final folderUri = Uri.directory(file.parent.path);
                if (await canLaunchUrl(folderUri)) {
                  await launchUrl(folderUri);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
