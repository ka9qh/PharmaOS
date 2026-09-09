import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  
  print('=== MEDICINES ===');
  print(db.select('SELECT id, name_ar, medicine_type, purchase_price, selling_price, qty_per_strip, strip_purchase_price, strip_selling_price, qty_per_pack, pack_purchase_price, pack_selling_price, qty_per_carton, carton_purchase_price, carton_selling_price FROM medicines WHERE id = 8622'));
  
  print('=== PURCHASE ITEMS ===');
  final items = db.select('SELECT id, purchase_id, medicine_id, quantity, unit_cost, subtotal, unit_name, selected_quantity, qty_carton, qty_pack, qty_strip, qty_pill FROM purchase_items');
  for (final it in items) {
    print(it);
  }
  
  print('=== SALES ===');
  final sales = db.select('SELECT id, invoice_number, total_amount, status FROM sales');
  for (final s in sales) {
    print(s);
  }

  print('=== SALE ITEMS ===');
  final sitems = db.select('SELECT id, sale_id, medicine_id, batch_id, quantity, unit_price, subtotal, unit_name, selected_quantity FROM sale_items');
  for (final sit in sitems) {
    print(sit);
  }

  print('=== RETURNS ===');
  final rets = db.select('SELECT id, sale_id, purchase_id, total_amount, settlement_method FROM returns');
  for (final r in rets) {
    print(r);
  }

  print('=== RETURN ITEMS ===');
  final ritems = db.select('SELECT * FROM return_items');
  for (final rit in ritems) {
    print(rit);
  }
  
  db.dispose();
}
