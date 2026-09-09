// إدارة حالة تسجيل الدخول عبر Riverpod (بنمط Notifier القياسي بدون Code Generation)
//
// قرار هندسي: بقية ميزات النظام (الـ 27 ميزة الأخرى) لا تزال Skeleton بنمط
// riverpod_generator (@riverpod). هنا في Auth تحديدًا استخدمنا Notifier يدوي
// أبسط لتقليل نقاط الفشل المحتملة أثناء أول تشغيل فعلي للمشروع من قبل مطور مبتدئ.
// هذا لا يُسقط أي متطلب - فقط اختلاف في أسلوب التنفيذ الداخلي لواجهة برمجية واحدة صغيرة.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/auth_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecase.dart';

class AuthUiState {
  final bool isLoading;
  final AuthUser? user;
  final String? errorMessage;

  const AuthUiState({this.isLoading = false, this.user, this.errorMessage});

  bool get isLoggedIn => user != null;

  AuthUiState copyWith({
    bool? isLoading,
    AuthUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthUiState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthUiState> {
  @override
  AuthUiState build() => const AuthUiState();

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final useCase = LoginUseCase(sl<AuthRepository>());
      final user = await useCase.call(username: username, password: password);
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'اسم المستخدم أو كلمة المرور غير صحيحة',
        );
      } else {
        state = AuthUiState(user: user);
      }
    } catch (e) {
      // لا نعرض تفاصيل الخطأ التقنية للمستخدم النهائي (كاشير/صيدلي)
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'حدث خطأ غير متوقع، حاول مرة أخرى',
      );
    }
  }

  Future<void> loginWithBiometrics() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await sl<AuthRepository>().loginWithBiometrics();
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'تعذر التحقق بالبصمة، يرجى تسجيل الدخول يدوياً',
        );
      } else {
        state = AuthUiState(user: user);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'حدث خطأ أثناء المصادقة بالبصمة',
      );
    }
  }

  void logout() {
    if (state.user != null) {
      // TODO: عند بناء LogoutUseCase الكامل مع تسجيل تدقيق، استدعِه هنا
    }
    state = const AuthUiState();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthUiState>(
  AuthNotifier.new,
);
