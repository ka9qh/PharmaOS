import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notifications_provider.dart';
import '../widgets/notifications_widget.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('التنبيهات')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty
                ? const Center(child: Text('لا توجد تنبيهات حاليًا ✓'))
                : ListView.builder(
                    itemCount: state.items.length,
                    itemBuilder: (context, index) => NotificationTile(notification: state.items[index]),
                  ),
      ),
    );
  }
}
