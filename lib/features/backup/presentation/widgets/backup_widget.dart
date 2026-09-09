import 'package:flutter/material.dart';
import '../../domain/entities/backup_entity.dart';

class BackupFileTile extends StatelessWidget {
  final BackupFileInfo backup;
  const BackupFileTile({super.key, required this.backup});

  String _formatDateTime(DateTime dt) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.save_outlined),
      title: Text(backup.fileName, style: const TextStyle(fontSize: 13)),
      subtitle: Text('${_formatDateTime(backup.createdAt)} • ${backup.sizeReadable}'),
    );
  }
}
