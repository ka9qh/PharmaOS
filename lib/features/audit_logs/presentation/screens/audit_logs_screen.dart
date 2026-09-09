import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/audit_logs_provider.dart';
import '../widgets/audit_logs_widget.dart';

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditLogsNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('سجل العمليات (Audit Log)')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: state.items.length,
                itemBuilder: (context, index) => AuditLogTile(entry: state.items[index]),
              ),
      ),
    );
  }
}
