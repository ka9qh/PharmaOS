import 'dart:io';
import 'dart:convert';

void main() {
  final files = [
    'assets/data/Scientific_all.csv',
    'assets/data/medicines_catalog.csv',
    'assets/data/Drugs_all.csv',
    'assets/data/Master_Medicines_Complete.csv',
    'assets/data/yemen_pharmacy_guide_medicines.csv',
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      print('File not found: $path');
      continue;
    }
    print('================================================================');
    print('FILE: $path');
    final lines = file.openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .take(5);

    lines.listen((line) {
      print('LINE: $line');
    });
  }
}
