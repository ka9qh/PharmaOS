import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/role_guard.dart';
import '../../../users/presentation/providers/users_provider.dart';
import '../../../users/domain/entities/users_entity.dart';
import '../providers/roles_provider.dart';

class RolesScreen extends ConsumerStatefulWidget {
  const RolesScreen({super.key});

  @override
  ConsumerState<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends ConsumerState<RolesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersNotifierProvider);
    
    final filteredUsers = usersState.items.where((user) {
      if (_searchQuery.isEmpty) return true;
      return user.fullName.contains(_searchQuery) || user.username.contains(_searchQuery);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('الصلاحيات والأدوار'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'بحث عن مستخدم...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            if (usersState.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(user.fullName[0]),
                        ),
                        title: Text(user.fullName),
                        subtitle: Text('الدور: ${RoleGuard.roleFromString(user.role).name} - ${user.username}'),
                        trailing: const Icon(Icons.security),
                        onTap: () {
                          _showPermissionsDialog(context, user);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPermissionsDialog(BuildContext context, UserAccountEntity user) {
    showDialog(
      context: context,
      builder: (context) {
        return UserPermissionsDialog(user: user);
      },
    );
  }
}

class UserPermissionsDialog extends ConsumerWidget {
  final UserAccountEntity user;

  const UserPermissionsDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overridesAsync = ref.watch(rolesProvider(user.id));
    final baseRole = RoleGuard.roleFromString(user.role);
    final defaults = RoleGuard.defaultsFor(baseRole);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('صلاحيات: ${user.fullName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: overridesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('خطأ: $err'),
            data: (overrides) {
              return ListView.builder(
                shrinkWrap: true,
                itemCount: AppPermission.values.length,
                itemBuilder: (context, index) {
                  final permission = AppPermission.values[index];
                  final isDefaultGranted = defaults.contains(permission);
                  
                  // if override exists, use it. Else use default.
                  final hasOverride = overrides.containsKey(permission);
                  final isGranted = hasOverride ? overrides[permission]! : isDefaultGranted;

                  return CheckboxListTile(
                    title: Text(RoleGuard.labelFor(permission)),
                    subtitle: Text(
                      hasOverride 
                        ? (isGranted ? 'مفعلة (استثناء)' : 'معطلة (استثناء)')
                        : (isDefaultGranted ? 'مفعلة (افتراضي)' : 'معطلة (افتراضي)'),
                      style: TextStyle(
                        color: hasOverride 
                          ? (isGranted ? Colors.green : Colors.red) 
                          : Colors.grey,
                      ),
                    ),
                    value: isGranted,
                    onChanged: (val) {
                      if (val == null) return;
                      // If the new value matches default, we just clear override.
                      // If it differs, we set override.
                      if (val == isDefaultGranted) {
                        ref.read(rolesProvider(user.id).notifier).togglePermission(permission, null);
                      } else {
                        ref.read(rolesProvider(user.id).notifier).togglePermission(permission, val);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
