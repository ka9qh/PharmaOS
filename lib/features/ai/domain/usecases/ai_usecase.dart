import '../entities/ai_entity.dart';
import '../repositories/ai_repository.dart';

class GenerateInsightsUseCase {
  final AiRepository _repo;
  const GenerateInsightsUseCase(this._repo);
  Future<List<AiInsight>> call() => _repo.generateInsights();
}
