// شاشة المصاريف والسحبيات - PharmaOS
// تدعم: فلترة شاملة (كل الفواتير، اليوم، يوم محدد، شهر وسنة، سنة كاملة، فترة مخصصة)،
// ربط المصروف بعمال الصيدلية، الدفع النقدي وعبر المحافظ، البحث الفوري، وعرض وطباعة سندات الصرف بالتفصيل.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/expenses_entity.dart';
import '../providers/expenses_provider.dart';
import '../../../workers/presentation/providers/workers_provider.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'سحبيات موظف / عامل',
    'إيجار الصيدلية',
    'كهرباء وطاقة',
    'ماء وخدمات',
    'صيانة ونظافة',
    'مستلزمات وأدوات',
    'أخرى (مصروف مخصص)',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // طباعة سند صرف مصروف
  Future<void> _printExpenseVoucher(ExpenseEntity exp) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final walletText = (exp.walletName != null && exp.walletName!.isNotEmpty)
        ? '${exp.paymentMethod} (${exp.walletName})'
        : exp.paymentMethod;
    final beneficiaryText = (exp.workerName != null && exp.workerName!.isNotEmpty)
        ? exp.workerName!
        : 'مصروف عام للصيدلية';
    final recorderText = (exp.recorderName != null && exp.recorderName!.isNotEmpty)
        ? exp.recorderName!
        : 'المحاسب المسجل';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 175 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('PharmaOS - الصيدلية الذكية', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text('سند صرف مصروف مالي', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 2),
                pw.Text('رقم السند: EXP-${exp.id}', style: const pw.TextStyle(fontSize: 9)),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('التاريخ والوقت:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(exp.createdAt), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('بند المصروف:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(exp.category, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('المستفيد / الساحب:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(beneficiaryText, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('طريقة الصرف / الخزينة:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(walletText, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('المحاسب المسجل:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(recorderText, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                if (exp.notes != null && exp.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('البيان والملاحظات:', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Text(exp.notes!, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.left),
                      ),
                    ],
                  ),
                ],
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المبلغ المصروف:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${exp.amount.toStringAsFixed(0)} ر.ي', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('المستلم / المستفيد', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 14),
                        pw.Text('....................', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('أمين الخزينة', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 14),
                        pw.Text('....................', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('المدير المسؤول', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 14),
                        pw.Text('....................', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text('سند صرف مالي رسمي معتمد - نظام PharmaOS', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // عرض تفاصيل سند الصرف
  void _showExpenseVoucherDetails(ExpenseEntity exp) {
    final walletText = (exp.walletName != null && exp.walletName!.isNotEmpty)
        ? '${exp.paymentMethod} (${exp.walletName})'
        : exp.paymentMethod;
    final beneficiaryText = (exp.workerName != null && exp.workerName!.isNotEmpty)
        ? exp.workerName!
        : 'مصروف عام للصيدلية';
    final recorderText = (exp.recorderName != null && exp.recorderName!.isNotEmpty)
        ? exp.recorderName!
        : 'المحاسب المسؤول';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: Colors.redAccent),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تفاصيل سند صرف المصروف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('رقم السند: EXP-${exp.id}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المبلغ المصروف:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(
                          '${exp.amount.toStringAsFixed(0)} ر.ي',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.category_outlined, 'بند المصروف', exp.category),
                  _buildDetailRow(Icons.person_outline, 'المستفيد / الساحب', beneficiaryText),
                  _buildDetailRow(Icons.account_balance_wallet_outlined, 'طريقة الصرف / الخزينة', walletText),
                  _buildDetailRow(Icons.badge_outlined, 'المحاسب المسجل', recorderText),
                  _buildDetailRow(Icons.access_time, 'التاريخ والوقت', DateFormat('yyyy-MM-dd HH:mm').format(exp.createdAt)),
                  _buildDetailRow(Icons.notes, 'البيان والملاحظات', (exp.notes != null && exp.notes!.isNotEmpty) ? exp.notes! : 'لا توجد ملاحظات إضافية'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
              icon: const Icon(Icons.print),
              label: const Text('طباعة سند الصرف'),
              onPressed: () {
                Navigator.pop(ctx);
                _printExpenseVoucher(exp);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    String selectedCategory = _categories.first;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final customCategoryController = TextEditingController();
    final customBeneficiaryController = TextEditingController();
    
    // نوع المستفيد: 'worker' موظف بالصيدلية, 'custom' جهة خارجية, 'general' مصروف عام
    String beneficiaryType = 'worker';
    int? selectedWorkerId;
    String paymentMethod = 'نقدي';
    int? selectedWalletId;
    String? amountError;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final workersState = ref.watch(workersNotifierProvider);
          final walletsAsync = ref.watch(walletsNotifierProvider);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.add_card, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('تسجيل سند صرف مصروف جديد'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // بند المصروف
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'بند المصروف *',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCategory = val;
                              if (val == 'سحبيات موظف / عامل') {
                                beneficiaryType = 'worker';
                              }
                            });
                          }
                        },
                      ),
                      if (selectedCategory == 'أخرى (مصروف مخصص)') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: customCategoryController,
                          decoration: const InputDecoration(
                            labelText: 'اكتب اسم البند المخصص *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // تحديد المستفيد / الساحب
                      const Text('المستفيد / جهة الصرف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('موظف بالصيدلية'),
                              selected: beneficiaryType == 'worker',
                              onSelected: (_) => setDialogState(() => beneficiaryType = 'worker'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('مستفيد / جهة خارجية'),
                              selected: beneficiaryType == 'custom',
                              onSelected: (_) => setDialogState(() => beneficiaryType = 'custom'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('مصروف عام للصيدلية'),
                              selected: beneficiaryType == 'general',
                              onSelected: (_) => setDialogState(() => beneficiaryType = 'general'),
                            ),
                          ],
                        ),
                      ),

                      if (beneficiaryType == 'worker') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'اختر الموظف المستلم / الساحب *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          value: selectedWorkerId,
                          items: workersState.workers
                              .map((w) => DropdownMenuItem(value: w.id, child: Text('${w.name} (${w.role})')))
                              .toList(),
                          onChanged: (val) => setDialogState(() => selectedWorkerId = val),
                        ),
                      ] else if (beneficiaryType == 'custom') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: customBeneficiaryController,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستفيد / جهة الصرف الخارجية (مثل: محصل الكهرباء، مالك العقار، فني الصيانة) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      // المبلغ
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'المبلغ المصروف *',
                          border: const OutlineInputBorder(),
                          suffixText: 'ر.ي',
                          errorText: amountError,
                        ),
                      ),

                      const SizedBox(height: 14),
                      // طريقة الدفع
                      const Text('طريقة الصرف / الخزينة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('نقدي (من الصندوق)'),
                            selected: paymentMethod == 'نقدي',
                            onSelected: (_) => setDialogState(() => paymentMethod = 'نقدي'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('محفظة إلكترونية'),
                            selected: paymentMethod == 'محفظة',
                            onSelected: (_) => setDialogState(() => paymentMethod = 'محفظة'),
                          ),
                        ],
                      ),

                      if (paymentMethod == 'محفظة') ...[
                        const SizedBox(height: 10),
                        walletsAsync.when(
                          data: (wallets) => DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'اختر المحفظة (جيب، جوالي...)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            value: selectedWalletId ?? (wallets.isNotEmpty ? wallets.first.id : null),
                            items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                            onChanged: (val) => setDialogState(() => selectedWalletId = val),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text('تعذر تحميل المحافظ'),
                        ),
                      ],

                      const SizedBox(height: 14),
                      // ملاحظات والبيان
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'البيان / الغرض من الصرف والملاحظات (اختياري)',
                          hintText: 'مثال: إيجار شهر سبتمبر، صيانة التكييف المركزي، فاتورة كهرباء عداد رقم 45...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  icon: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: const Text('تسجيل واعتماد السند'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final amt = double.tryParse(amountController.text) ?? 0;
                          if (amt <= 0) {
                            setDialogState(() => amountError = 'يرجى إدخال مبلغ صحيح');
                            return;
                          }
                          setDialogState(() => isSaving = true);

                          final finalCategory = selectedCategory == 'أخرى (مصروف مخصص)' && customCategoryController.text.trim().isNotEmpty
                              ? customCategoryController.text.trim()
                              : selectedCategory;

                          int? finalWorkerId;
                          String? finalCustomWorkerName;

                          if (beneficiaryType == 'worker') {
                            finalWorkerId = selectedWorkerId;
                          } else if (beneficiaryType == 'custom' && customBeneficiaryController.text.trim().isNotEmpty) {
                            finalCustomWorkerName = customBeneficiaryController.text.trim();
                          }

                          final currentUserId = ref.read(authNotifierProvider).user?.id;

                          final ok = await ref.read(expensesNotifierProvider.notifier).add(
                                category: finalCategory,
                                amount: amt,
                                notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                workerId: finalWorkerId,
                                customWorkerName: finalCustomWorkerName,
                                paymentMethod: paymentMethod,
                                walletId: selectedWalletId,
                                recordedBy: currentUserId,
                              );

                          if (ok && mounted && ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم قيد سند صرف المصروف بنجاح ✓'), backgroundColor: Colors.green),
                            );
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesNotifierProvider);
    final notifier = ref.read(expensesNotifierProvider.notifier);
    final currentYear = DateTime.now().year;

    String filterDescription;
    switch (state.filterMode) {
      case ExpenseFilterMode.all:
        filterDescription = 'جميع المصاريف والفواتير بدون تحديد تاريخ';
        break;
      case ExpenseFilterMode.today:
        filterDescription = 'مصاريف اليوم (${DateFormat('yyyy-MM-dd').format(DateTime.now())})';
        break;
      case ExpenseFilterMode.singleDate:
        filterDescription = 'مصاريف يوم: ${DateFormat('yyyy-MM-dd').format(state.selectedDate ?? DateTime.now())}';
        break;
      case ExpenseFilterMode.fullYear:
        filterDescription = 'مصاريف سنة ${state.selectedYear} كاملة';
        break;
      case ExpenseFilterMode.dateRange:
        filterDescription = 'مصاريف من ${DateFormat('yyyy-MM-dd').format(state.fromDate ?? DateTime.now())} إلى ${DateFormat('yyyy-MM-dd').format(state.toDate ?? DateTime.now())}';
        break;
      case ExpenseFilterMode.monthYear:
        filterDescription = 'مصاريف شهر ${state.selectedMonth} / ${state.selectedYear}';
        break;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('سجل المصاريف والسحبيات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث المصاريف',
              onPressed: () => notifier.loadExpenses(),
            ),
          ],
        ),
        body: Column(
          children: [
            // شريط الفلترة بالتاريخ والبحث
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // شريط الأزرار للفلترة السريعة (الكل، اليوم، يوم محدد، شهر وسنة، سنة كاملة، فترة)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          selected: state.filterMode == ExpenseFilterMode.all,
                          label: const Text('📋 عرض الفواتير كاملة (الكل)'),
                          selectedColor: Colors.blue.shade100,
                          onSelected: (_) => notifier.showAll(),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          selected: state.filterMode == ExpenseFilterMode.today,
                          label: const Text('📅 اليوم'),
                          selectedColor: Colors.teal.shade100,
                          onSelected: (_) => notifier.setToday(),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          selected: state.filterMode == ExpenseFilterMode.singleDate,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event, size: 16),
                              const SizedBox(width: 4),
                              Text(state.filterMode == ExpenseFilterMode.singleDate
                                  ? 'يوم: ${DateFormat('yyyy-MM-dd').format(state.selectedDate ?? DateTime.now())}'
                                  : '🗓️ يوم محدد'),
                            ],
                          ),
                          selectedColor: Colors.amber.shade100,
                          onSelected: (_) async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: state.selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              notifier.setSingleDate(picked);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          selected: state.filterMode == ExpenseFilterMode.monthYear,
                          label: const Text('📆 شهر وسنة'),
                          selectedColor: Colors.purple.shade100,
                          onSelected: (_) => notifier.setPeriod(state.selectedYear, state.selectedMonth),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          selected: state.filterMode == ExpenseFilterMode.fullYear,
                          label: Text('🏛️ سنة كاملة (${state.selectedYear})'),
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (_) => notifier.setFullYear(state.selectedYear),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          selected: state.filterMode == ExpenseFilterMode.dateRange,
                          label: const Text('⏱️ فترة مخصصة'),
                          selectedColor: Colors.green.shade100,
                          onSelected: (_) async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              initialDateRange: DateTimeRange(
                                start: state.fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
                                end: state.toDate ?? DateTime.now(),
                              ),
                            );
                            if (range != null) {
                              notifier.setDateRange(range.start, range.end);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // أدوات تحديد الشهر والسنة إن تم اختيار فلتر شهر وسنة أو سنة كاملة
                  if (state.filterMode == ExpenseFilterMode.monthYear || state.filterMode == ExpenseFilterMode.fullYear)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          if (state.filterMode == ExpenseFilterMode.monthYear) ...[
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: state.selectedMonth,
                                decoration: const InputDecoration(
                                  labelText: 'الشهر',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: List.generate(12, (i) => i + 1)
                                    .map((m) => DropdownMenuItem(value: m, child: Text('شهر $m')))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    notifier.setPeriod(state.selectedYear, val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: state.selectedYear,
                              decoration: const InputDecoration(
                                labelText: 'السنة',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [currentYear - 2, currentYear - 1, currentYear, currentYear + 1]
                                  .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  if (state.filterMode == ExpenseFilterMode.fullYear) {
                                    notifier.setFullYear(val);
                                  } else {
                                    notifier.setPeriod(val, state.selectedMonth);
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  // شريط البحث وزر إضافة مصروف
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Colors.blue),
                            hintText: 'ابحث في المصاريف (البند، الملاحظات، اسم الموظف)...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          onChanged: (val) => notifier.setSearchQuery(val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('تسجيل مصروف جديد'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _showAddExpenseDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ملخص الفلتر النشط والإجمالي
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'عرض: $filterDescription (${state.items.length} سند)',
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'إجمالي المصاريف: ${state.totalAmount.toStringAsFixed(0)} ر.ي',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // قائمة المصاريف
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد مصاريف مسجلة حسب الفلتر المحدد ($filterDescription)',
                                style: const TextStyle(fontSize: 15, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: state.items.length,
                          itemBuilder: (context, index) {
                            final exp = state.items[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showExpenseVoucherDetails(exp),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.red.shade50,
                                        radius: 22,
                                        child: const Icon(Icons.money_off, color: Colors.redAccent, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  exp.category,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: (exp.workerName != null && exp.workerName!.isNotEmpty)
                                                        ? Colors.blue.shade50
                                                        : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    (exp.workerName != null && exp.workerName!.isNotEmpty)
                                                        ? 'المستفيد: ${exp.workerName}'
                                                        : 'مصروف عام للصيدلية',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: (exp.workerName != null && exp.workerName!.isNotEmpty)
                                                          ? Colors.blue.shade800
                                                          : Colors.grey.shade700,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  '${exp.amount.toStringAsFixed(0)} ر.ي',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'سند EXP-${exp.id} | ${DateFormat('yyyy-MM-dd HH:mm').format(exp.createdAt)} | ${exp.walletName != null ? '${exp.paymentMethod} (${exp.walletName})' : exp.paymentMethod}${exp.recorderName != null ? " | المحاسب: ${exp.recorderName}" : ""}',
                                                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('عرض السند', style: TextStyle(fontSize: 11, color: Colors.blue)),
                                                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            if (exp.notes != null && exp.notes!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: Text(
                                                  'البيان: ${exp.notes}',
                                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
