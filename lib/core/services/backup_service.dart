// نسخ احتياطي تلقائي مرقّم (Versioned) لملف قاعدة البيانات المشفرة بالكامل
// (الملف يبقى مشفّرًا في النسخة الاحتياطية أيضًا - لا حاجة لإعادة تشفيره).
// راجع docs/BACKUP_STRATEGY.md - لا تُستبدل آخر نسخة أبدًا.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/db_constants.dart';

class BackupFileInfo {
  final String fileName;
  final String filePath;
  final int sizeBytes;
  final DateTime createdAt;

  const BackupFileInfo({
    required this.fileName,
    required this.filePath,
    required this.sizeBytes,
    required this.createdAt,
  });

  String get sizeReadable {
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    final kb = sizeBytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }
}

class BackupService {
  Future<Directory> _backupsDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> createBackup() async {
    final supportDir = await getApplicationSupportDirectory();
    final dbFile = File(p.join(supportDir.path, DbConstants.databaseFileName));

    if (!await dbFile.exists()) {
      // لا توجد قاعدة بيانات بعد (أول تشغيل قبل أي عملية) - لا شيء لنسخه احتياطيًا
      return null;
    }

    final backupsDir = await _backupsDir();
    final now = DateTime.now();
    final stamp = '${now.year}-${_two(now.month)}-${_two(now.day)}_${_two(now.hour)}-${_two(now.minute)}';
    final backupFile = File(p.join(backupsDir.path, 'pharmaos_backup_$stamp.db'));

    await dbFile.copy(backupFile.path);
    return backupFile.path;
  }

  /// يسرد كل النسخ الاحتياطية الموجودة فعليًا على القرص، الأحدث أولًا.
  Future<List<BackupFileInfo>> listBackups() async {
    final dir = await _backupsDir();
    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.db'))
        .cast<File>()
        .toList();

    final infos = <BackupFileInfo>[];
    for (final file in files) {
      final stat = await file.stat();
      infos.add(BackupFileInfo(
        fileName: p.basename(file.path),
        filePath: file.path,
        sizeBytes: stat.size,
        createdAt: stat.modified,
      ));
    }

    infos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return infos;
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
