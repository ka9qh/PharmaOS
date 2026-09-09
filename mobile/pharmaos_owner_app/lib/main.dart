// نقطة انطلاق تطبيق المدير - PharmaOS Owner App
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/owner_api_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await OwnerApiService.getConfig();
  runApp(PharmaOSOwnerApp(initialConfig: config));
}

class PharmaOSOwnerApp extends StatelessWidget {
  final dynamic initialConfig;

  const PharmaOSOwnerApp({super.key, this.initialConfig});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaOS Owner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Cairo',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ar', 'SA'),
      home: initialConfig != null ? const MainNavigationScreen() : const LoginScreen(),
    );
  }
}
