import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/automated_backup_service.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  bool _isAutoSyncEnabled = false;
  String? _syncDirectory;
  bool _isSyncingNow = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoSyncEnabled = prefs.getBool('auto_cloud_sync') ?? false;
      _syncDirectory = prefs.getString('cloud_sync_dir');
    });
    
    // إعادة تهيئة الخدمة
    AutomatedBackupService().configure(
      enableAutoSync: _isAutoSyncEnabled,
      syncDirectory: _syncDirectory,
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_cloud_sync', _isAutoSyncEnabled);
    if (_syncDirectory != null) {
      await prefs.setString('cloud_sync_dir', _syncDirectory!);
    } else {
      await prefs.remove('cloud_sync_dir');
    }
    
    AutomatedBackupService().configure(
      enableAutoSync: _isAutoSyncEnabled,
      syncDirectory: _syncDirectory,
    );
  }

  Future<void> _selectDirectory() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد المزامنة (مثل مجلد Google Drive أو OneDrive)',
    );
    
    if (dir != null) {
      setState(() => _syncDirectory = dir);
      await _saveSettings();
    }
  }

  Future<void> _syncNow() async {
    if (_syncDirectory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار مجلد المزامنة أولاً')));
      return;
    }
    
    setState(() => _isSyncingNow = true);
    
    final success = await AutomatedBackupService().performSync();
    
    setState(() => _isSyncingNow = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'تمت المزامنة بنجاح ✅' : 'فشلت المزامنة ❌'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('المزامنة السحابية (Cloud Sync)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'اربط النظام بمجلد Google Drive أو OneDrive الخاص بك للحصول على مزامنة سحابية تلقائية ومجانية لبياناتك.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('تفعيل المزامنة التلقائية'),
              subtitle: const Text('يقوم النظام بنسخ البيانات تلقائياً للمجلد المحدد'),
              value: _isAutoSyncEnabled,
              onChanged: (val) {
                setState(() => _isAutoSyncEnabled = val);
                _saveSettings();
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('مجلد المزامنة السحابية'),
              subtitle: Text(_syncDirectory ?? 'لم يتم تحديد مجلد (اضغط للاختيار)'),
              trailing: const Icon(Icons.folder_open),
              onTap: _selectDirectory,
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                icon: _isSyncingNow 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.sync),
                label: const Text('مزامنة الآن'),
                onPressed: _isSyncingNow ? null : _syncNow,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
