import 'dart:io';
import 'package:csv/csv.dart';

void main() {
  print('--- Checking medicines_catalog.csv ---');
  final f1 = File('c:\\pharmasy\\PharmaOS\\assets\\data\\medicines_catalog.csv');
  if (f1.existsSync()) {
    final content = f1.readAsStringSync();
    final rows = const CsvToListConverter().convert(content);
    print('Total rows in medicines_catalog: ${rows.length}');
    if (rows.isNotEmpty) {
      print('Headers: ${rows.first}');
      for (var i = 1; i <= 5; i++) {
        print('\nRow $i:');
        print('  Name: ${rows[i][1]} (${rows[i][0]})');
        print('  Scientific: ${rows[i][2]}');
        print('  Form: ${rows[i][5]}');
        print('  Dosage: ${rows[i][6]}');
      }
    }
  }

  print('\n--- Checking Scientific_all.csv ---');
  final f2 = File('c:\\pharmasy\\PharmaOS\\assets\\data\\Scientific_all.csv');
  if (f2.existsSync()) {
    final lines = f2.readAsLinesSync();
    print('Total lines in Scientific_all: ${lines.length}');
    print('Header: ${lines.first}');
    int withUseCount = 0;
    for (var i = 1; i < lines.length && i < 1000; i++) {
      if (lines[i].contains('يستخدم') || lines[i].contains('الجرعة') || lines[i].contains('الأطفال') || lines[i].contains('البالغين')) {
        withUseCount++;
        if (withUseCount <= 3) {
          print('\nSample $withUseCount: ${lines[i]}');
        }
      }
    }
    print('Found $withUseCount sample lines with clinical keywords in first 1000 lines');
  }
}
