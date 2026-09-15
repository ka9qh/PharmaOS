// شاشة تفعيل الترخيص - أول شاشة تظهر إذا لم يوجد ترخيص صالح لهذا الجهاز.
// راجع docs/LICENSING_STRATEGY.md لآلية العمل الكاملة.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/device_branch_manager_service.dart';

import '../providers/licensing_provider.dart';
import '../controllers/licensing_controller.dart';
import '../widgets/licensing_widget.dart';

class LicensingScreen extends ConsumerStatefulWidget {
  const LicensingScreen({super.key});

  @override
  ConsumerState<LicensingScreen> createState() => _LicensingScreenState();
}

class _LicensingScreenState extends ConsumerState<LicensingScreen> {
  final _keyController = TextEditingController();
  String? _keyError;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final error = LicensingController.validateLicenseKey(_keyController.text);
    setState(() => _keyError = error);
    if (error != null) return;

    final ok = await ref.read(licensingNotifierProvider.notifier).activate(_keyController.text.trim());
    if (ok && mounted) {
      final isFirstRunDone = await DeviceBranchManagerService.isFirstRunCompleted();
      if (!isFirstRunDone) {
        context.go('/onboarding');
      } else {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(licensingNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: state.isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 56),
                        const SizedBox(height: 8),
                        Text('تفعيل PharmaOS', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        const Text(
                          'هذا الجهاز غير مُفعَّل بعد. أرسل معرف الجهاز أدناه لمزوّد النظام '
                          'واحصل على مفتاح التفعيل الخاص بك.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        if (state.hardwareId != null) HardwareIdCard(hardwareId: state.hardwareId!),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _keyController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'مفتاح التفعيل',
                            hintText: 'الصق المفتاح الذي استلمته هنا',
                            errorText: _keyError,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (state.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(state.errorMessage!,
                                style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: state.isActivating ? null : _activate,
                            child: state.isActivating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('تفعيل وتشغيل'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.teal),
                          label: const Text('تشغيل معالج التهيئة الشامل (Onboarding Wizard)'),
                          onPressed: () => context.go('/onboarding'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        bottomNavigationBar: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'جميع الحقوق محفوظة © م/عباد السويدي\nللتواصل: +967776065503',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
