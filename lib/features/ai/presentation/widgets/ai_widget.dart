import 'package:flutter/material.dart';
import '../../domain/entities/ai_entity.dart';

class InsightCard extends StatelessWidget {
  final AiInsight insight;
  const InsightCard({super.key, required this.insight});

  Color get _color {
    switch (insight.severity) {
      case InsightSeverity.critical:
        return Colors.red;
      case InsightSeverity.warning:
        return Colors.orange;
      case InsightSeverity.info:
        return Colors.blue;
    }
  }

  IconData get _icon {
    switch (insight.severity) {
      case InsightSeverity.critical:
        return Icons.error_outline;
      case InsightSeverity.warning:
        return Icons.warning_amber_rounded;
      case InsightSeverity.info:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _color.withOpacity(0.08),
      child: ListTile(
        leading: Icon(_icon, color: _color),
        title: Text(insight.message),
      ),
    );
  }
}
