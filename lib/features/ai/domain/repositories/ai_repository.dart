import '../entities/ai_entity.dart';

abstract class AiRepository {
  /// يولّد قائمة رؤى نصية بالعربية من بيانات التحليلات والمخزون الحالية.
  /// كل الرؤى مبنية على معادلات/استعلامات صريحة (Rule-Based) - لا يوجد أي
  /// نموذج ذكاء اصطناعي توليدي هنا. راجع docs/AI_DEVELOPMENT_GUIDE.md.
  Future<List<AiInsight>> generateInsights();
}
