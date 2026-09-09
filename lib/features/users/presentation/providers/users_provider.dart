import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/security/role_guard.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/users_entity.dart';
import '../../domain/repositories/users_repository.dart';
import '../../domain/usecases/users_usecase.dart';

class UsersState {
  final bool isLoading;
  final List<UserAccountEntity> items;
  final String? errorMessage;

  const UsersState({this.isLoading = false, this.items = const [], this.errorMessage});

  UsersState copyWith({
    bool? isLoading,
    List<UserAccountEntity>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UsersState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class UsersNotifier extends AutoDisposeNotifier<UsersState> {
  @override
  UsersState build() {
    Future.microtask(loadAll);
    return const UsersState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await ListUsersUseCase(sl<UsersRepository>()).call();
      state = state.copyWith(isLoading: false, items: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر تحميل المستخدمين');
    }
  }

  Future<bool> add({
    required String fullName,
    required String username,
    required String password,
    required AppRole role,
  }) async {
    try {
      await CreateUserUseCase(sl<UsersRepository>())
          .call(fullName: fullName, username: username, password: password, role: role);
      await loadAll();
      return true;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إضافة المستخدم');
      return false;
    }
  }

  Future<void> setActive(int userId, bool isActive) async {
    await SetUserActiveUseCase(sl<UsersRepository>()).call(userId, isActive);
    await loadAll();
  }

  Future<bool> resetPassword(int userId, String newPassword) async {
    try {
      await ResetPasswordUseCase(sl<UsersRepository>()).call(userId, newPassword);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر إعادة تعيين كلمة المرور');
      return false;
    }
  }
}

final usersNotifierProvider = AutoDisposeNotifierProvider<UsersNotifier, UsersState>(UsersNotifier.new);
