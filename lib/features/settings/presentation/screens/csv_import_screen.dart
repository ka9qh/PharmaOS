import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/import_drugs_usecase.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  String? _selectedDirectory;
  bool _isBusy = false;
  ImportDrugsResult? _result;
  String? _error;

  Future<void> _pickDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      setState(() {
        _selectedDirectory = path;
        _error = null;
        _result = null;
      });
    }
  }

  Future<void> _startImport() async {
    if (_selectedDirectory == null) return;
    setState(() {
      _isBusy = true;
      _error = null;
      _result = null;
    });

    final usecase = sl<ImportDrugsUseCase>();
    final res = await usecase.call(_selectedDirectory!);

    setState(() {
      _isBusy = false;
      if (res.error != null) {
        _error = res.error;
      } else {
        _result = res;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استيراد قاعدة الأدوية المتقدمة (CSV)'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تقوم هذه الأداة بقراءة 4 ملفات CSV مترابطة (الرئيسي، العلمي، الشركات، الوكلاء) ودمجها بذكاء مع قاعدة البيانات الحالية للنظام.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'يجب أن يحتوي المجلد الذي تختاره على الملفات التالية بالأسماء الدقيقة:\n'
                '1. Drugs_all.csv\n'
                '2. Scientific_all.csv\n'
                '3. Companies_all.csv\n'
                '4. Proxies_all.csv',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      controller: TextEditingController(text: _selectedDirectory ?? 'لم يتم اختيار مجلد'),
                      decoration: const InputDecoration(
                        labelText: 'مسار المجلد',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isBusy ? null : _pickDirectory,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('اختيار المجلد'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: FilledButton.icon(
                  onPressed: (_isBusy || _selectedDirectory == null) ? null : _startImport,
                  icon: _isBusy 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.cloud_upload),
                  label: const Text('بدء عملية الاستيراد'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              if (_result != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.check_circle_outline, color: Colors.green),
                          SizedBox(width: 8),
                          Text('تمت عملية الاستيراد بنجاح!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('• تم إدراج أدوية جديدة: ${_result!.addedCount}'),
                      Text('• تم تحديث أدوية موجودة: ${_result!.updatedCount}'),
                      Text('• تم إدراج شركات جديدة: ${_result!.companiesAdded}'),
                      Text('• تم إدراج وكلاء جُدد: ${_result!.suppliersAdded}'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
