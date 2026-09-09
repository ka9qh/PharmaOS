// شاشة الرؤى الذكية - نصوص مبنية على معادلات وقواعد صريحة، وليست ذكاءً توليديًا
// راجع docs/AI_DEVELOPMENT_GUIDE.md للمبدأ الكامل.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ai_provider.dart';
import '../widgets/ai_widget.dart';

class AiScreen extends ConsumerWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('الرؤى والتوصيات')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: state.insights.map((i) => InsightCard(insight: i)).toList(),
              ),
      ),
    );
  }
}
