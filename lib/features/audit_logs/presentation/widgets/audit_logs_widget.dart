import 'package:flutter/material.dart';
import '../../domain/entities/audit_logs_entity.dart';

class AuditLogTile extends StatelessWidget {
  final AuditLogEntryEntity entry;
  const AuditLogTile({super.key, required this.entry});

  String _formatTime(DateTime dt) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}  ${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.history, size: 20),
      title: Text(entry.friendlyDescription),
      subtitle: Text('${entry.userName ?? 'النظام'} • ${_formatTime(entry.timestamp)}'),
    );
  }
}
