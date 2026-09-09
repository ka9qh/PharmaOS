import 'package:flutter/material.dart';
import '../../domain/entities/users_entity.dart';

class UserListTile extends StatelessWidget {
  final UserAccountEntity user;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onManagePermissions;
  final bool canManage;

  const UserListTile({
    super.key,
    required this.user,
    required this.onActiveChanged,
    required this.onManagePermissions,
    required this.canManage,
  });

  String get _roleLabel {
    switch (user.role.name) {
      case 'owner':
        return 'مالك';
      case 'manager':
        return 'مدير';
      case 'accountant':
        return 'محاسب';
      case 'pharmacist':
        return 'صيدلي';
      case 'cashier':
        return 'كاشير';
      case 'inventoryClerk':
        return 'مسؤول مخزون';
      case 'employee':
        return 'موظف';
      default:
        return user.role.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(user.fullName.isNotEmpty ? user.fullName[0] : '?')),
      title: Text(user.fullName),
      subtitle: Text('${user.username} • $_roleLabel'),
      trailing: canManage
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.security, color: Colors.blue),
                  onPressed: onManagePermissions,
                  tooltip: 'تخصيص الصلاحيات',
                ),
                Switch(value: user.isActive, onChanged: onActiveChanged),
              ],
            )
          : Text(user.isActive ? 'نشط' : 'معطّل'),
    );
  }
}
