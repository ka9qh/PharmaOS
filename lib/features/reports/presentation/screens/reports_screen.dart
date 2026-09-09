// شاشة التقارير وإغلاق النوبة - PharmaOS (مُصحَّحة)
//
// تصحيح مهم: هذا الزر لا "يقفل" اليوم ولا يمنع أي عملية لاحقة. يمكن الضغط
// عليه عدة مرات في نفس اليوم التقويمي - كل ضغطة تُصدر تقريرًا (PDF+Excel+نسخة
// احتياطية) عن الفترة منذ آخر إصدار وحتى الآن، مناسب لصيدليات العمل بنظام
// النوبات (24 ساعة، أكثر من عامل، كل عامل يُصدر تقرير فترته).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reports_provider.dart';
import '../controllers/reports_controller.dart';
import '../widgets/reports_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/floating_ai_assistant.dart';

import '../../../../core/utils/currency_formatter.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  String _formatDateTime(DateTime dt) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _confirmClose(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إصدار تقرير إغلاق'),
        content: const Text(
          'سيتم إنشاء نسخة احتياطية وتقرير PDF وExcel يغطي الفترة منذ آخر إغلاق '
          'وحتى الآن. هذا لن يمنع تسجيل أي عملية بيع أو شراء أو مصروف لاحقًا. متابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إصدار التقرير')),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ref.read(reportsNotifierProvider.notifier).closeCurrentPeriod();
    if (ok && context.mounted) {
      final result = ref.read(reportsNotifierProvider).lastResult;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم إصدار التقرير بنجاح ✓'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('صافي الربح لهذه الفترة: ${CurrencyFormatter.format(result?.summary.netProfit ?? 0)}'),
              const SizedBox(height: 8),
              const Text('تم حفظ الملفات في:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(result?.reportPdfPath ?? '', style: const TextStyle(fontSize: 11)),
              Text(result?.reportExcelPath ?? '', style: const TextStyle(fontSize: 11)),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا')),
          ],
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف تقرير الإغلاق'),
        content: const Text(
          'هذا إجراء حساس يُسجَّل في سجل التدقيق ولا يمكن التراجع عنه. '
          'ملفات PDF/Excel المحفوظة على القرص لن تُحذف، فقط سجل هذا الإغلاق من النظام. متابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(reportsNotifierProvider.notifier).deleteClosingRecord(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsNotifierProvider);
    final currentUser = ref.watch(authNotifierProvider).user;
    final canDelete = currentUser != null && ReportsController.canDeleteClosingRecord(currentUser);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('التقارير وإغلاق النوبة')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.lastClosingTime != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'آخر تقرير صادر: ${_formatDateTime(state.lastClosingTime!)}',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (state.preview != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'أرقام الفترة الحالية (منذ ${_formatDateTime(state.preview!.periodStart)})',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const Divider(),
                            SummaryRow(label: 'إجمالي المبيعات', value: state.preview!.totalSales),
                            SummaryRow(label: 'إجمالي المرتجعات', value: state.preview!.totalReturns),
                            SummaryRow(
                                label: 'تكلفة البضاعة المباعة', value: state.preview!.costOfGoodsSold),
                            SummaryRow(label: 'إجمالي المصاريف', value: state.preview!.totalExpenses),
                            SummaryRow(
                                label: 'التسديدات للموردين',
                                value: state.preview!.totalVendorPayments),
                            const Divider(),
                            SummaryRow(
                                label: 'صافي الربح',
                                value: state.preview!.netProfit,
                                bold: true,
                                color: state.preview!.netProfit >= 0 ? Colors.green : Colors.red),
                            SummaryRow(
                                label: 'النقدية المتوقعة بالصندوق',
                                value: state.preview!.cashInDrawer,
                                bold: true),
                            if (state.preview!.lowStockItems.isNotEmpty) ...[
                              const Divider(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text('⚠ أدوية تحتاج إعادة طلب (${state.preview!.lowStockItems.length})',
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                              ...state.preview!.lowStockItems.map(
                                (s) => Text('- ${s.medicineName}: متبقي ${s.totalQuantity}'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: state.isClosing ? null : () => _confirmClose(context, ref),
                        icon: state.isClosing
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.description_outlined),
                        label: const Text('إصدار تقرير الآن'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade50),
                        onPressed: () {
                          FloatingAiDialog.show(
                            context,
                            initialMessage: 'قم بتحليل مبيعات الفترات السابقة وأعطني تقرير تنبؤي بالأدوية التي قد يزيد الطلب عليها هذا الشهر (توقع موسمي بناءً على الوقت الحالي).',
                          );
                        },
                        icon: const Icon(Icons.auto_awesome, color: Colors.indigo),
                        label: const Text('التنبؤ بالمبيعات بواسطة الذكاء الاصطناعي', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 24),
                  Text('سجل التقارير السابقة', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...state.recentClosings.map((record) => Card(
                        child: ListTile(
                          title: Text(_formatDateTime(record.createdAt)),
                          subtitle: Text(
                            'الفترة منذ ${_formatDateTime(record.periodStart)}\n'
                            'صافي الربح: ${CurrencyFormatter.format(record.netProfit)} • النقدية: ${record.cashInDrawer.toStringAsFixed(0)}',
                          ),
                          isThreeLine: true,
                          trailing: canDelete
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'حذف هذا التقرير',
                                  onPressed: () => _confirmDelete(context, ref, record.id),
                                )
                              : null,
                        ),
                      )),
                ],
              ),
      ),
    );
  }
}
