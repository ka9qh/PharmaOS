import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

void main() async {
  final appData = Platform.environment['APPDATA'] ?? '';
  final dbPath = p.join(appData, 'com.example', 'pharmaos', 'pharmaos_secure.db');
  print('Checking db at: $dbPath');
  final file = File(dbPath);
  if (!file.existsSync()) {
    print('DB file does not exist at $dbPath');
    return;
  }
  print('DB file size: ${file.lengthSync()} bytes');
}
