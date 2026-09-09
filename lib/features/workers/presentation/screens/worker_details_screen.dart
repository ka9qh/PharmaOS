import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:drift/drift.dart' as drift;

import '../../domain/entities/workers_entity.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';

class WorkerDetailsScreen extends ConsumerStatefulWidget {
  final WorkerEntity worker;
  const WorkerDetailsScreen({super.key, required this.worker});

  @override
  ConsumerState<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends ConsumerState<WorkerDetailsScreen> {
  List<ExpenseRow> _advances = [];
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadWorkerAdvances();
  }

  Future<void> _loadWorkerAdvances() async {
    if (widget.worker.id == null) return;
    setState(() => _isLoading = true);
    final db = sl<AppDatabase>();
    var query = db.select(db.expenses)..where((e) => e.workerId.equals(widget.worker.id!));

    if (_selectedDateRange != null) {
      query = query
        ..where((e) =>
            e.createdAt.isBiggerOrEqualValue(_selectedDateRange!.start) &
            e.createdAt.isSmallerOrEqualValue(_selectedDateRange!.end.add(const Duration(days: 1))));
    }

    final list = await (query..orderBy([(e) => drift.OrderingTerm.desc(e.createdAt)])).get();
    if (mounted) {
      setState(() {
        _advances = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.ي', decimalDigits: 0);
    final totalAdvances = _advances.fold<double>(0, (sum, a) => sum + a.amount);
    final remainingSalary = widget.worker.salary - totalAdvances;

    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('كشف حساب وسجل مسحوبات الموظف', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 16),
              pw.Text('اسم الموظف: ${widget.worker.name}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('الوظيفة / الدور: ${widget.worker.role}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('رقم الهاتف: ${widget.worker.phone ?? "غير مسجل"}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('الراتب الشهري الأساسي: ${currencyFormat.format(widget.worker.salary)}', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('سجل المسحوبات والسلفيات:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['التاريخ والوقت', 'البند', 'المبلغ المسحوب', 'طريقة الصرف', 'ملاحظات'],
                data: _advances.map((e) => [
                  DateFormat('yyyy/MM/dd HH:mm').format(e.createdAt),
                  e.category,
                  currencyFormat.format(e.amount),
                  e.paymentMethod,
                  e.notes ?? '',
                ]).toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('إجمالي المسحوبات: ${currencyFormat.format(totalAdvances)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('المتبقي من الراتب: ${currencyFormat.format(remainingSalary)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text('تاريخ التصدير: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كشف_حساب_${widget.worker.name}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.ي', decimalDigits: 0);
    final totalAdvances = _advances.fold<double>(0, (sum, a) => sum + a.amount);
    final remainingSalary = widget.worker.salary - totalAdvances;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text('كشف حساب الموظف: ${widget.worker.name}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'تصدير وطباعة كشف الحساب (PDF)',
              onPressed: _exportPdf,
            ),
          ],
        ),
        body: Column(
          children: [
            // بطاقة بيانات الموظف والراتب
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(Icons.person, size: 30, color: Colors.blue),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.worker.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text('الوظيفة: ${widget.worker.role} | الهاتف: ${widget.worker.phone ?? "غير محدد"}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Text('الراتب الشهري', style: TextStyle(fontSize: 12, color: Colors.blue)),
                              Text(currencyFormat.format(widget.worker.salary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Text('إجمالي المسحوبات', style: TextStyle(fontSize: 12, color: Colors.red)),
                              Text(currencyFormat.format(totalAdvances), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Text('المتبقي من الراتب', style: TextStyle(fontSize: 12, color: Colors.green)),
                              Text(currencyFormat.format(remainingSalary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // شريط فلترة الفترة الزمنية
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  const Text('سجل المسحوبات والسلفيات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      _selectedDateRange != null
                          ? '${DateFormat('MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('MM/dd').format(_selectedDateRange!.end)}'
                          : 'فلترة الفترة',
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: _selectedDateRange,
                      );
                      if (picked != null) {
                        setState(() => _selectedDateRange = picked);
                        _loadWorkerAdvances();
                      }
                    },
                  ),
                  if (_selectedDateRange != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                      onPressed: () {
                        setState(() => _selectedDateRange = null);
                        _loadWorkerAdvances();
                      },
                    ),
                  ],
                ],
              ),
            ),

            // جدول المسحوبات
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _advances.isEmpty
                      ? const Center(child: Text('لا توجد مسحوبات أو سلفيات مسجلة لهذا الموظف في الفترة المحددة'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _advances.length,
                          itemBuilder: (context, index) {
                            final adv = _advances[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.redAccent,
                                  child: Icon(Icons.money_off, color: Colors.white, size: 18),
                                ),
                                title: Text(adv.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(adv.createdAt)} | طريقة الصرف: ${adv.paymentMethod}'),
                                trailing: Text(
                                  currencyFormat.format(adv.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
