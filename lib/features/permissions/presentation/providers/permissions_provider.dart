// Feature: permissions
// Layer: presentation/providers
//
// نمط Notifier اليدوي (بدون @riverpod codegen) - نفس اختيار auth_provider.dart
// وusers_provider.dart، لتفادي الاعتماد على build_runner لتفعيل هذه الشاشة.
// (الملف المولَّد القديم permissions_provider.g.dart أصبح غير مستخدم - يمكن
// حذفه بأمان، أو تركه فلن يُستورد من أي مكان).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/security/role_guard.dart';
import '../../domain/entities/permissions_entity.dart';
import '../../domain/repositories/permissions_repository.dart';
import '../../domain/usecases/permissions_usecase.dart';
import '../../../users/domain/entities/users_entity.dart';

class PermissionsState {
  final bool isLoading;
  final List<UserAccountEntity> users;
  final UserAccountEntity? selectedUser;
  final List<UserPermissionEntity> permissions;
  final String? errorMessage;

  const PermissionsState({
    this.isLoading = false,
    this.users = const [],
    this.selectedUser,
    this.permissions = const [],
    this.errorMessage,
  });

  PermissionsState copyWith({
    bool? isLoading,
    List<UserAccountEntity>? users,
    UserAccountEntity? selectedUser,
    List<UserPermissionEntity>? permissions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PermissionsState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      selectedUser: selectedUser ?? this.selectedUser,
      permissions: permissions ?? this.permissions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PermissionsNotifier extends AutoDisposeNotifier<PermissionsState> {
  @override
  PermissionsState build() {
    Future.microtask(loadUsers);
    return const PermissionsState();
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final users = await ListUsersForPermissionsUseCase(sl<PermissionsRepository>()).call();
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل المستخدمين');
    }
  }

  Future<void> selectUser(UserAccountEntity user) async {
    state = state.copyWith(isLoading: true, selectedUser: user, clearError: true);
    try {
      final permissions =
          await GetUserPermissionsUseCase(sl<PermissionsRepository>()).call(user.id, user.role);
      state = state.copyWith(isLoading: false, permissions: permissions);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل صلاحيات المستخدم');
    }
  }

  Future<void> toggle(AppPermission permission, bool granted, int changedByUserId) async {
    final user = state.selectedUser;
    if (user == null) return;
    await SetPermissionOverrideUseCase(sl<PermissionsRepository>()).call(
      userId: user.id,
      permission: permission,
      granted: granted,
      changedByUserId: changedByUserId,
    );
    await selectUser(user); // إعادة تحميل لعرض الحالة الفعلية المُحدَّثة فورًا
  }

  Future<void> resetToRoleDefault(AppPermission permission, int changedByUserId) async {
    final user = state.selectedUser;
    if (user == null) return;
    await ClearPermissionOverrideUseCase(sl<PermissionsRepository>()).call(
      userId: user.id,
      permission: permission,
      changedByUserId: changedByUserId,
    );
    await selectUser(user);
  }
}

final permissionsNotifierProvider =
    AutoDisposeNotifierProvider<PermissionsNotifier, PermissionsState>(PermissionsNotifier.new);
