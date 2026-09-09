import '../../domain/entities/ai_entity.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/ai_datasource.dart';

class AiRepositoryImpl implements AiRepository {
  final AiDataSource dataSource;
  AiRepositoryImpl(this.dataSource);

  @override
  Future<List<AiInsight>> generateInsights() => dataSource.generateInsights();
}
