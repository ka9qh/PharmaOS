import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/security/role_guard.dart';
import '../../../../core/security/permissions_service.dart';
import '../../domain/entities/users_entity.dart';

class UserPermissionsScreen extends ConsumerStatefulWidget {
  final UserAccountEntity user;
  const UserPermissionsScreen({super.key, required this.user});

  @override
  ConsumerState<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends ConsumerState<UserPermissionsScreen> {
  bool _isLoading = true;
  late Set<AppPermission> _effectivePermissions;
  late Set<AppPermission> _defaultPermissions;

  @override
  void initState() {
    super.initState();
    _defaultPermissions = RoleGuard.defaultsFor(widget.user.role);
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    final perms = await ref.read(permissionsServiceProvider).effectivePermissionsFor(widget.user.id, widget.user.role);
    setState(() {
      _effectivePermissions = perms;
      _isLoading = false;
    });
  }

  Future<void> _togglePermission(AppPermission permission, bool isGranted) async {
    setState(() {
      if (isGranted) {
        _effectivePermissions.add(permission);
      } else {
        _effectivePermissions.remove(permission);
      }
    });
    
    final currentUser = ref.read(authNotifierProvider).user;
    if (isGranted) {
      await ref.read(permissionsServiceProvider).setOverride(
        userId: widget.user.id, 
        permission: permission, 
        granted: true, 
        changedByUserId: currentUser?.id ?? 1
      );
    } else {
      if (_defaultPermissions.contains(permission)) {
        await ref.read(permissionsServiceProvider).setOverride(
          userId: widget.user.id, 
          permission: permission, 
          granted: false, 
          changedByUserId: currentUser?.id ?? 1
        );
      } else {
        await ref.read(permissionsServiceProvider).clearOverride(
          userId: widget.user.id, 
          permission: permission, 
          changedByUserId: currentUser?.id ?? 1
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('صلاحيات المستخدم: ${widget.user.fullName}'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: AppPermission.values.length,
                itemBuilder: (context, index) {
                  final perm = AppPermission.values[index];
                  final isGranted = _effectivePermissions.contains(perm);
                  final isDefault = _defaultPermissions.contains(perm);

                  return Card(
                    child: SwitchListTile(
                      title: Text(RoleGuard.labelFor(perm), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: isDefault 
                          ? const Text('هذه الصلاحية ممنوحة افتراضياً بناءً على دور المستخدم.', style: TextStyle(color: Colors.green, fontSize: 12))
                          : const Text('هذه الصلاحية غير ممنوحة افتراضياً.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      value: isGranted,
                      onChanged: (val) => _togglePermission(perm, val),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
