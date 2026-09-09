// Feature: permissions
// Layer: presentation/widgets

import 'package:flutter/material.dart';
import '../../domain/entities/permissions_entity.dart';
import '../../../../core/security/role_guard.dart';

class PermissionToggleTile extends StatelessWidget {
  final UserPermissionEntity item;
  final bool canEdit;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onReset;

  const PermissionToggleTile({
    super.key,
    required this.item,
    required this.canEdit,
    required this.onChanged,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(RoleGuard.labelFor(item.permission)),
      subtitle: item.isOverridden
          ? const Text('مخصَّص يدويًا لهذا المستخدم', style: TextStyle(color: Colors.orange))
          : const Text('افتراضي الدور', style: TextStyle(color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.isOverridden && canEdit)
            IconButton(
              tooltip: 'إعادة لافتراضي الدور',
              icon: const Icon(Icons.restart_alt, size: 20),
              onPressed: onReset,
            ),
          Switch(value: item.effective, onChanged: canEdit ? onChanged : null),
        ],
      ),
    );
  }
}
