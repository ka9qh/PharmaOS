enum InsightSeverity { info, warning, critical }

class AiInsight {
  final String message;
  final InsightSeverity severity;

  const AiInsight({required this.message, required this.severity});
}
