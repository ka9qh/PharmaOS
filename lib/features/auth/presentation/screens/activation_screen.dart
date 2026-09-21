import 'package:flutter/material.dart';
import '../../../../core/services/license_service.dart';
import '../../../../core/utils/app_colors.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _licenseCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  bool _isLoading = false;
  String _errorMsg = '';
  bool _isMultiBranch = false;

  Future<void> _activate() async {
    final license = _licenseCtrl.text.trim();
    final branch = _branchCtrl.text.trim();

    if (license.isEmpty) {
      setState(() => _errorMsg = 'الرجاء إدخال رمز التفعيل الخاص بالصيدلية');
      return;
    }
    
    if (_isMultiBranch && branch.isEmpty) {
      setState(() => _errorMsg = 'الرجاء إدخال رمز تفعيل الفرع');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    final success = await LicenseService.activateLicense(
      licenseKey: license,
      branchActivationKey: _isMultiBranch ? branch : null,
    );

    if (!mounted) return;

    if (success) {
      // إعادة التشغيل للتطبيق لضمان تطبيق الإعدادات
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg = 'رمز التفعيل غير صحيح، أو الحساب موقوف، يرجى مراجعة الدعم الفني.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.security, size: 60, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text(
                'تفعيل النظام',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'الرجاء إدخال رمز التفعيل الخاص بك للبدء باستخدام النظام',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _licenseCtrl,
                decoration: const InputDecoration(
                  labelText: 'رمز تفعيل الصيدلية',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Checkbox(
                    value: _isMultiBranch,
                    onChanged: (val) {
                      setState(() => _isMultiBranch = val ?? false);
                    },
                  ),
                  const Text('تفعيل كفرع تابع (Multi-Branch)'),
                ],
              ),
              if (_isMultiBranch) ...[
                const SizedBox(height: 15),
                TextField(
                  controller: _branchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رمز تفعيل الفرع',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                ),
              ],
              if (_errorMsg.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  _errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _activate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تفعيل وتأكيد', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
