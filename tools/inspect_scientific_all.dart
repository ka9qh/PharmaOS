import 'dart:io';
import 'package:csv/csv.dart';

void main() {
  final f = File('c:\\pharmasy\\PharmaOS\\assets\\data\\Scientific_all.csv');
  final lines = f.readAsLinesSync();
  print('Total lines in Scientific_all: ${lines.length}');
  print('Header: ${lines.first}');

  int nonEmptyUses = 0;
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    final parts = const CsvToListConverter().convert(line);
    if (parts.isNotEmpty && parts.first.length >= 5) {
      final useEn = parts.first[3].toString().trim();
      final useAr = parts.first[4].toString().trim();
      if (useAr.isNotEmpty || useEn.isNotEmpty) {
        nonEmptyUses++;
        if (nonEmptyUses <= 5) {
          print('\nSci Name AR: ${parts.first[2]} (EN: ${parts.first[1]})');
          print('  Use AR: $useAr');
          print('  Use EN: $useEn');
        }
      }
    }
  }

  print('\nTotal scientific records with uses: $nonEmptyUses / ${lines.length}');
}
