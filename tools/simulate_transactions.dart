import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

import 'package:path/path.dart' as p;

void main() {
  final appData = Platform.environment['APPDATA'];
  if (appData == null) {
    print('❌ خطأ: لم يتم العثور على مسار APPDATA.');
    return;
  }

  final possiblePaths = [
    p.join(appData, 'com.example', 'PharmaOS', 'pharmaos_secure.db'),
    p.join(appData, 'com.example', 'pharmaos', 'pharmaos_secure.db'),
    p.join(appData, 'PharmaOS', 'pharmaos_secure.db'),
    p.join(appData, 'pharmasy', 'PharmaOS', 'pharmaos_secure.db'),
  ];

  String? dbPath;
  for (final path in possiblePaths) {
    if (File(path).existsSync()) {
      dbPath = path;
      break;
    }
  }

  if (dbPath == null) {
    print('Database not found in possible paths');
    return;
  }

  print('--- بدء عملية الاختبار الشامل (System Testing) ---');
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  try {
    // 1. إضافة مورد جديد
    db.execute("INSERT INTO suppliers (name, contact_info, balance) VALUES ('شركة باير للأدوية', '0123456789', 0)");
    final supplierId = db.lastInsertRowId;
    print('✅ تم إنشاء مورد بنجاح. معرف: $supplierId');

    // 2. فاتورة مشتريات آجلة من المورد
    db.execute('''
      INSERT INTO purchases (supplier_id, invoice_number, total_amount, discount, payment_method, status, created_at)
      VALUES ($supplierId, 'INV-BUY-1001', 50000, 0, 'آجل', 'completed', datetime('now'))
    ''');
    final purchaseId = db.lastInsertRowId;
    print('✅ تم تسجيل فاتورة مشتريات بقيمة 50,000 ريال. الفاتورة: $purchaseId');

    // إدخال الأدوية في الفاتورة (Batches)
    // سنجد أول دواء في قاعدة البيانات
    final medRow = db.select('SELECT id, name FROM medicines LIMIT 1');
    if (medRow.isEmpty) throw Exception('لا يوجد أدوية في النظام للاختبار.');
    final medId = medRow.first['id'];
    final medName = medRow.first['name'];
    print('   - جلب الدواء: $medName (معرف: $medId)');

    db.execute('''
      INSERT INTO batches (medicine_id, batch_number, expiry_date, quantity, purchase_price, selling_price, created_at)
      VALUES ($medId, 'B-TEST-001', datetime('now', '+1 year'), 100, 500, 700, datetime('now'))
    ''');
    final batchId = db.lastInsertRowId;
    
    db.execute('''
      INSERT INTO purchase_items (purchase_id, batch_id, quantity, unit_price, subtotal)
      VALUES ($purchaseId, $batchId, 100, 500, 50000)
    ''');

    // 3. تسديد دفعة للمورد
    db.execute('''
      INSERT INTO vendor_payments (supplier_id, amount, payment_method, notes, created_at)
      VALUES ($supplierId, 20000, 'نقدي', 'دفعة من الحساب', datetime('now'))
    ''');
    print('✅ تم تسديد دفعة للمورد بقيمة 20,000 ريال');

    // 4. مبيعات نقدية
    db.execute('''
      INSERT INTO sales (invoice_number, total_amount, discount, payment_method, status, created_at)
      VALUES ('INV-SALE-1001', 7000, 0, 'نقدي', 'completed', datetime('now'))
    ''');
    final saleId1 = db.lastInsertRowId;
    
    db.execute('''
      INSERT INTO sale_items (sale_id, batch_id, quantity, unit_price, subtotal)
      VALUES ($saleId1, $batchId, 10, 700, 7000)
    ''');
    db.execute('UPDATE batches SET quantity = quantity - 10 WHERE id = $batchId');
    print('✅ تم تسجيل مبيعات نقدية بقيمة 7,000 ريال');

    // 5. المصروفات
    db.execute('''
      INSERT INTO expenses (category, amount, description, created_at)
      VALUES ('ضيافة', 1000, 'قهوة وشاي', datetime('now'))
    ''');
    print('✅ تم تسجيل مصروفات بقيمة 1,000 ريال');

    // --- حسابات الوردية (التحقق من الإغلاق) ---
    print('\\n--- تقرير الإغلاق المالي (محاكاة) ---');
    final salesRow = db.select("SELECT IFNULL(SUM(total_amount),0) as s FROM sales").first['s'] as num;
    final expRow = db.select("SELECT IFNULL(SUM(amount),0) as e FROM expenses").first['e'] as num;
    final vpRow = db.select("SELECT IFNULL(SUM(amount),0) as v FROM vendor_payments").first['v'] as num;
    
    // Cost of goods sold (10 units * 500 purchase price = 5000)
    final cogsRow = db.select('''
      SELECT IFNULL(SUM(si.quantity * b.purchase_price), 0) as cogs
      FROM sale_items si JOIN batches b ON b.id = si.batch_id
    ''').first['cogs'] as num;

    final netProfit = salesRow - cogsRow - expRow;
    final cash = salesRow - expRow - vpRow;

    print('إجمالي المبيعات: $salesRow');
    print('تكلفة البضاعة (COGS): $cogsRow');
    print('المصروفات: $expRow');
    print('المدفوعات للموردين: $vpRow');
    print('صافي الربح للوردية: $netProfit');
    print('النقدية بالصندوق: $cash');

    // التأكد من الأرقام
    assert(cogsRow == 5000, 'خطأ في حساب التكلفة');
    assert(netProfit == (7000 - 5000 - 1000), 'خطأ في حساب الربح');
    assert(cash == (7000 - 1000 - 20000), 'خطأ في حساب النقدية');

    print('\\n✅ تمت محاكاة جميع العمليات بنجاح واختبار الحسابات بشكل صحيح 100%.');

  } catch (e) {
    print('❌ حدث خطأ أثناء الاختبار: $e');
  }

  db.dispose();
}
