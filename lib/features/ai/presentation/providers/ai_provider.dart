import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/ai_entity.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/usecases/ai_usecase.dart';

class AiState {
  final bool isLoading;
  final List<AiInsight> insights;
  final String? errorMessage;

  const AiState({this.isLoading = false, this.insights = const [], this.errorMessage});

  AiState copyWith({bool? isLoading, List<AiInsight>? insights, String? errorMessage}) {
    return AiState(
      isLoading: isLoading ?? this.isLoading,
      insights: insights ?? this.insights,
      errorMessage: errorMessage,
    );
  }
}

class AiNotifier extends AutoDisposeNotifier<AiState> {
  @override
  AiState build() {
    Future.microtask(loadInsights);
    return const AiState();
  }

  Future<void> loadInsights() async {
    state = state.copyWith(isLoading: true);
    try {
      final insights = await GenerateInsightsUseCase(sl<AiRepository>()).call();
      state = state.copyWith(isLoading: false, insights: insights);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'تعذر توليد الرؤى');
    }
  }
}

final aiNotifierProvider = AutoDisposeNotifierProvider<AiNotifier, AiState>(AiNotifier.new);
