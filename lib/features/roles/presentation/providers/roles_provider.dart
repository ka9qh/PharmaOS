import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/security/permissions_service.dart';
import '../../../../core/security/role_guard.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

part 'roles_provider.g.dart';

@riverpod
class Roles extends _$Roles {
  @override
  FutureOr<Map<AppPermission, bool>> build(int userId) async {
    final service = ref.watch(permissionsServiceProvider);
    return await service.getOverrides(userId);
  }

  Future<void> togglePermission(AppPermission permission, bool? isGranted) async {
    final service = ref.read(permissionsServiceProvider);
    final authUser = ref.read(authNotifierProvider).user;
    if (authUser == null) return;

    if (isGranted == null) {
      await service.clearOverride(userId: userId, permission: permission, changedByUserId: authUser.id);
    } else {
      await service.setOverride(userId: userId, permission: permission, granted: isGranted, changedByUserId: authUser.id);
    }
    
    // Refresh overrides
    ref.invalidateSelf();
  }
}
