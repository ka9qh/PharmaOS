import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AutomatedBackupService {
  static final AutomatedBackupService _instance = AutomatedBackupService._internal();
  factory AutomatedBackupService() => _instance;
  AutomatedBackupService._internal();

  Timer? _backupTimer;
  String? _syncDirectory;
  bool _isAutoSyncEnabled = false;

  void configure({required bool enableAutoSync, String? syncDirectory}) {
    _isAutoSyncEnabled = enableAutoSync;
    _syncDirectory = syncDirectory;
    
    if (_isAutoSyncEnabled && _syncDirectory != null) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    // تنفيذ النسخ التلقائي كل 12 ساعة كمثال (يمكن ربطه بوقت محدد لاحقاً)
    _backupTimer = Timer.periodic(const Duration(hours: 12), (timer) {
      performSync();
    });
  }

  void _stopTimer() {
    _backupTimer?.cancel();
    _backupTimer = null;
  }

  Future<bool> performSync() async {
    if (_syncDirectory == null || _syncDirectory!.isEmpty) return false;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docDir.path, 'pharmaos', 'pharmaos.sqlite');
      
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return false;

      final now = DateTime.now();
      final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour}-${now.minute}';
      
      final backupFileName = 'pharmaos_backup_$timestamp.sqlite';
      final backupPath = p.join(_syncDirectory!, backupFileName);

      await dbFile.copy(backupPath);
      debugPrint('تمت المزامنة السحابية بنجاح إلى: $backupPath');
      return true;
    } catch (e) {
      debugPrint('خطأ في المزامنة السحابية: $e');
      return false;
    }
  }
}
