// شاشة إدارة المستخدمين - Owner أو من يملك manageUsers فقط للتعديل
// بدون هذه الشاشة، حساب admin الافتراضي كان سيبقى المستخدم الوحيد الممكن
// إطلاقًا في النظام - ضرورية لأي صيدلية فيها أكثر من موظف.
//
// تحديث: canManage أصبح يعتمد على currentUser.can(...) (الصلاحيات الفعلية
// بعد التخصيص الفردي) بدل RoleGuard.can(role, ...) (افتراضي الدور فقط) -
// حتى يعمل تخصيص manageUsers لمستخدم معيّن عبر شاشة الصلاحيات الجديدة فعليًا.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/users_provider.dart';
import '../controllers/users_controller.dart';
import '../widgets/users_widget.dart';
import 'user_permissions_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/security/role_guard.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final fullNameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    AppRole selectedRole = AppRole.cashier;
    String? fullNameError, usernameError, passwordError;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة مستخدم جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameController,
                  decoration: InputDecoration(labelText: 'الاسم الكامل', errorText: fullNameError),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(labelText: 'اسم المستخدم', errorText: usernameError),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة مرور مبدئية',
                    errorText: passwordError,
                    helperText: 'سيُطلب من المستخدم تغييرها عند أول دخول',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AppRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'الدور'),
                  items: const [
                    DropdownMenuItem(value: AppRole.manager, child: Text('مدير')),
                    DropdownMenuItem(value: AppRole.accountant, child: Text('محاسب')),
                    DropdownMenuItem(value: AppRole.pharmacist, child: Text('صيدلي')),
                    DropdownMenuItem(value: AppRole.cashier, child: Text('كاشير')),
                    DropdownMenuItem(value: AppRole.inventoryClerk, child: Text('مسؤول مخزون')),
                    DropdownMenuItem(value: AppRole.employee, child: Text('موظف')),
                  ],
                  onChanged: (value) => setState(() => selectedRole = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final result = UsersController.validate(
                  fullName: fullNameController.text,
                  username: usernameController.text,
                  password: passwordController.text,
                );
                setState(() {
                  fullNameError = result.fullNameError;
                  usernameError = result.usernameError;
                  passwordError = result.passwordError;
                });
                if (!result.isValid) return;

                final ok = await ref.read(usersNotifierProvider.notifier).add(
                      fullName: fullNameController.text,
                      username: usernameController.text,
                      password: passwordController.text,
                      role: selectedRole,
                    );
                if (ok && context.mounted) Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersNotifierProvider);
    final currentUser = ref.watch(authNotifierProvider).user;
    final canManage = currentUser != null && currentUser.can(AppPermission.manageUsers);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المستخدمون')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (!canManage)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'للعرض فقط - إضافة أو تعطيل المستخدمين يتطلب صلاحية إدارة المستخدمين',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.items.length,
                      itemBuilder: (context, index) {
                        final user = state.items[index];
                        return UserListTile(
                          user: user,
                          canManage: canManage,
                          onManagePermissions: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => UserPermissionsScreen(user: user),
                              ),
                            );
                          },
                          onActiveChanged: (value) =>
                              ref.read(usersNotifierProvider.notifier).setActive(user.id, value),
                        );
                      },
                    ),
                  ),
                ],
              ),
        floatingActionButton: canManage
            ? FloatingActionButton(
                onPressed: () => _showAddDialog(context, ref),
                child: const Icon(Icons.person_add_alt_1),
              )
            : null,
      ),
    );
  }
}
