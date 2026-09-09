// Feature: barcode
// Layer: presentation/screens
// TODO: شاشة "بحث بالباركود" مستقلة (لاختبار قارئ الباركود يدويًا خارج شاشة POS)
// ستُبنى فعليًا في Phase 3 عند بناء نقطة البيع، حيث سيُستخدم فيها
// core/hardware/barcode_scanner_listener.dart للاستماع لمدخلات القارئ.

import 'package:flutter/material.dart';

class BarcodeScreen extends StatelessWidget {
  const BarcodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('شاشة اختبار الباركود - تُبنى في Phase 3 (POS)')),
    );
  }
}
