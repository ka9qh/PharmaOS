import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbFile = File(r'C:\Users\hp\AppData\Roaming\com.example\pharmaos\pharmaos_secure.db');
  if (!dbFile.existsSync()) {
    print('DB not found: ${dbFile.path}');
    return;
  }

  final db = sqlite3.open(dbFile.path);
  print('Opened DB successfully.');

  final suppliers = db.select('SELECT id, name FROM suppliers');
  print('Suppliers count: ${suppliers.length}');
  for (final s in suppliers) {
    print('Supplier ID: ${s['id']}, Name: ${s['name']}');
    final purchases = db.select('SELECT COUNT(*) as cnt, SUM(total_amount) as total, SUM(paid_amount) as paid FROM purchases WHERE supplier_id = ?', [s['id']]);
    print('  Purchases: ${purchases.first['cnt']}, Total: ${purchases.first['total']}, Paid: ${purchases.first['paid']}');
    final payments = db.select('SELECT COUNT(*) as cnt, SUM(amount) as paid FROM vendor_payments WHERE supplier_id = ?', [s['id']]);
    print('  Vendor Payments: ${payments.first['cnt']}, Paid: ${payments.first['paid']}');
  }

  db.dispose();
}
