import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app_theme.dart';
import '../core/constants/app_constants.dart';

class PharmaOSApp extends StatelessWidget {
  final GoRouter router;
  final Widget Function(BuildContext, Widget?)? builder;

  const PharmaOSApp({super.key, required this.router, this.builder});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: builder,
    );
  }
}
