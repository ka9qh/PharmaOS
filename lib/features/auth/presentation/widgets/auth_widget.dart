// عنصر مشترك: شعار وعنوان النظام أعلى شاشة تسجيل الدخول

import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

class AuthLogoHeader extends StatelessWidget {
  const AuthLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.local_pharmacy_rounded, size: 64),
        const SizedBox(height: 8),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'نظام إدارة الصيدلية',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
