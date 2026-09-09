import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';

import '../../../../core/di/service_locator.dart';
import '../../../medicines/domain/entities/medicines_entity.dart';
import '../../../medicines/domain/repositories/medicines_repository.dart';

class BarcodePrintItem {
  final MedicineEntity medicine;
  int quantity;

  BarcodePrintItem({required this.medicine, this.quantity = 1});
}

class BarcodePrintingScreen extends ConsumerStatefulWidget {
  const BarcodePrintingScreen({super.key});

  @override
  ConsumerState<BarcodePrintingScreen> createState() => _BarcodePrintingScreenState();
}

class _BarcodePrintingScreenState extends ConsumerState<BarcodePrintingScreen> {
  final _searchController = TextEditingController();
  final List<MedicineEntity> _searchResults = [];
  final List<BarcodePrintItem> _printList = [];
  bool _isSearching = false;

  // إعدادات مقاسات الطابعات الحرارية الشائعة (العرض × الارتفاع ملم)
  double _labelWidth = 50.0;
  double _labelHeight = 25.0;

  final TextEditingController _widthCtrl = TextEditingController(text: '50');
  final TextEditingController _heightCtrl = TextEditingController(text: '25');

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }
    setState(() => _isSearching = true);
    try {
      final repo = sl<MedicinesRepository>();
      final results = await repo.getAll(searchQuery: query);
      if (mounted) {
        setState(() {
          _searchResults
            ..clear()
            ..addAll(results.where((m) => m.barcode != null && m.barcode!.isNotEmpty));
        });
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _addToList(MedicineEntity med) {
    setState(() {
      final existing = _printList.indexWhere((e) => e.medicine.id == med.id);
      if (existing >= 0) {
        _printList[existing].quantity++;
      } else {
        _printList.add(BarcodePrintItem(medicine: med));
      }
      _searchController.clear();
      _searchResults.clear();
    });
  }

  Future<void> _generateAndPrintPDF() async {
    if (_printList.isEmpty) return;

    final doc = pw.Document();
    
    // تحويل المقاس من ملم إلى نقاط PDF (1 ملم = 2.83465 نقطة تقريباً)
    final format = PdfPageFormat(
      _labelWidth * PdfPageFormat.mm,
      _labelHeight * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm, // هامش صغير جداً 2 ملم
    );

    // تحميل الخط العربي
    // سنستخدم الخط الافتراضي كـ fallback لكن يُفضل خط داعم للعربية إذا كان متوفراً
    // بما أننا نطبع باركودات صغيرة جداً قد لا تظهر العربية جيداً بدون خط مخصص،
    // لتبسيط الأمر سنركز على البيانات الممكنة.
    final ttf = await PdfGoogleFonts.cairoRegular();

    for (final item in _printList) {
      for (int i = 0; i < item.quantity; i++) {
        doc.addPage(
          pw.Page(
            pageFormat: format,
            build: (pw.Context context) {
              return pw.Container(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // اسم الدواء
                    pw.Text(
                      (item.medicine.nameEn ?? item.medicine.nameAr).length > 20 
                          ? (item.medicine.nameEn ?? item.medicine.nameAr).substring(0, 20) 
                          : (item.medicine.nameEn ?? item.medicine.nameAr),
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      maxLines: 1,
                    ),
                    pw.SizedBox(height: 2),
                    // الباركود
                    pw.Expanded(
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: item.medicine.barcode!,
                        drawText: true,
                        textStyle: const pw.TextStyle(fontSize: 7),
                        width: double.infinity,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    // السعر
                    pw.Text(
                      'Price: ${item.medicine.sellingPrice} YER',
                      style: pw.TextStyle(fontSize: 8, font: ttf),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat defaultFormat) async => doc.save(),
      name: 'PharmaOS_Barcodes',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طباعة ملصقات الباركود'),
          actions: [
            if (_printList.isNotEmpty)
              FilledButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('طباعة'),
                onPressed: _generateAndPrintPDF,
              ),
            const SizedBox(width: 16),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // إعدادات مقاس الورق
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('إعدادات الطابعة الحرارية: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _widthCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'العرض (ملم)', isDense: true),
                          onChanged: (v) => setState(() => _labelWidth = double.tryParse(v) ?? 50.0),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'الارتفاع (ملم)', isDense: true),
                          onChanged: (v) => setState(() => _labelHeight = double.tryParse(v) ?? 25.0),
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: '${_labelWidth.toInt()}x${_labelHeight.toInt()}',
                        items: const [
                          DropdownMenuItem(value: '50x25', child: Text('قياسي 50x25 ملم')),
                          DropdownMenuItem(value: '40x20', child: Text('صغير 40x20 ملم')),
                          DropdownMenuItem(value: '80x40', child: Text('كبير 80x40 ملم')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            final parts = v.split('x');
                            setState(() {
                              _widthCtrl.text = parts[0];
                              _heightCtrl.text = parts[1];
                              _labelWidth = double.parse(parts[0]);
                              _labelHeight = double.parse(parts[1]);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // حقل البحث
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'ابحث عن الدواء بالاسم أو الباركود',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                onChanged: _search,
              ),
              
              if (_searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Card(
                    elevation: 4,
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final med = _searchResults[index];
                        return ListTile(
                          title: Text(med.nameEn ?? med.nameAr),
                          subtitle: Text('الباركود: ${med.barcode} | السعر: ${med.sellingPrice}'),
                          trailing: const Icon(Icons.add_circle, color: Colors.blue),
                          onTap: () => _addToList(med),
                        );
                      },
                    ),
                  ),
                ),
                
              const SizedBox(height: 16),
              
              // قائمة الأدوية المضافة
              Expanded(
                child: _printList.isEmpty
                    ? const Center(child: Text('لم يتم إضافة أي أدوية للطباعة'))
                    : ListView.builder(
                        itemCount: _printList.length,
                        itemBuilder: (context, index) {
                          final item = _printList[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.qr_code),
                              title: Text(item.medicine.nameEn ?? item.medicine.nameAr),
                              subtitle: Text('الباركود: ${item.medicine.barcode}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('الكمية: '),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: item.quantity > 1
                                        ? () => setState(() => item.quantity--)
                                        : null,
                                  ),
                                  Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => setState(() => item.quantity++),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => setState(() => _printList.removeAt(index)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
