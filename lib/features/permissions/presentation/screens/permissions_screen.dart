// Feature: permissions
// Layer: presentation/screens
// شاشة الصلاحيات - Owner/من يملك manageUsers فقط للتعديل (عرض متاح للجميع،
// نفس فلسفة شاشة المستخدمين). راجع docs/PATCH_NOTES_2026_08_PERMISSIONS.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/permissions_provider.dart';
import '../widgets/permissions_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/security/role_guard.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  String _roleLabel(AppRole role) {
    switch (role) {
      case AppRole.owner:
        return 'مالك';
      case AppRole.manager:
        return 'مدير';
      case AppRole.accountant:
        return 'محاسب';
      case AppRole.pharmacist:
        return 'صيدلي';
      case AppRole.cashier:
        return 'كاشير';
      case AppRole.inventoryClerk:
        return 'مسؤول مخزون';
      case AppRole.employee:
        return 'موظف';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(permissionsNotifierProvider);
    final currentUser = ref.watch(authNotifierProvider).user;
    final canEdit = currentUser != null && currentUser.can(AppPermission.manageUsers);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الصلاحيات')),
        body: state.isLoading && state.users.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!canEdit)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'للعرض فقط - تعديل الصلاحيات يتطلب صلاحية إدارة المستخدمين',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: state.users.length,
                            itemBuilder: (context, index) {
                              final user = state.users[index];
                              final selected = state.selectedUser?.id == user.id;
                              return ListTile(
                                selected: selected,
                                leading: CircleAvatar(
                                    child: Text(user.fullName.isNotEmpty ? user.fullName[0] : '?')),
                                title: Text(user.fullName),
                                subtitle: Text(_roleLabel(user.role)),
                                onTap: () =>
                                    ref.read(permissionsNotifierProvider.notifier).selectUser(user),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: state.selectedUser == null
                        ? const Center(child: Text('اختر مستخدمًا من القائمة لعرض صلاحياته'))
                        : ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'صلاحيات: ${state.selectedUser!.fullName} '
                                  '(${_roleLabel(state.selectedUser!.role)})',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              ...state.permissions.map(
                                (item) => PermissionToggleTile(
                                  item: item,
                                  canEdit: canEdit,
                                  onChanged: (value) => ref
                                      .read(permissionsNotifierProvider.notifier)
                                      .toggle(item.permission, value, currentUser!.id),
                                  onReset: () => ref
                                      .read(permissionsNotifierProvider.notifier)
                                      .resetToRoleDefault(item.permission, currentUser!.id),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
