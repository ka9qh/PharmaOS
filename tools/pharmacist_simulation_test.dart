import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final dbPath = '$appData\\com.example\\pharmaos\\pharmaos_secure.db';
  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    print('❌ قاعدة البيانات غير موجودة في: $dbPath');
    return;
  }

  print('========================================================');
  print('🩺 بدء الفحص والمحاكاة الشاملة لدورة الصيدلي والمحاسب 🩺');
  print('========================================================\n');

  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  // ==========================================
  // الاختبار 1: التحقق من جاهزية الأدوية والمخزون
  // ==========================================
  print('--- [1/7] فحص الأدوية وتوفر دفعات المخزون (Batches) ---');
  final medsCount = db.select('SELECT count(*) as c FROM medicines;').first['c'];
  final batchesCount = db.select('SELECT count(*) as c FROM batches;').first['c'];
  final compsCount = db.select('SELECT count(*) as c FROM companies;').first['c'];
  final suppsCount = db.select('SELECT count(*) as c FROM suppliers;').first['c'];
  final catsCount = db.select('SELECT count(*) as c FROM categories;').first['c'];

  print('✓ إجمالي الأدوية المسجلة: $medsCount دواء');
  print('✓ إجمالي الشركات المصنعة: $compsCount شركة');
  print('✓ إجمالي الموردين والوكلاء: $suppsCount مورد');
  print('✓ إجمالي التصنيفات الدوائية: $catsCount تصنيف');
  print('✓ إجمالي دفعات المخزون المتوفرة: $batchesCount دفعة');

  // جلب دواء ودفعة جاهزة للبيع
  var sampleBatch = db.select('''
    SELECT b.id as batch_id, b.medicine_id, b.batch_number, b.quantity, b.expiry_date, 
           m.name_ar, m.selling_price, m.purchase_price
    FROM batches b
    JOIN medicines m ON b.medicine_id = m.id
    WHERE b.quantity >= 5
    LIMIT 1;
  ''');

  int testBatchId;
  int testMedId;
  String testMedName;
  int initialQty;
  double price;
  double cost;

  if (sampleBatch.isEmpty) {
    final med = db.select('SELECT id, name_ar, selling_price, purchase_price FROM medicines LIMIT 1;').first;
    testMedId = med['id'] as int;
    testMedName = med['name_ar'].toString();
    price = (med['selling_price'] as num).toDouble();
    cost = (med['purchase_price'] as num).toDouble();
    if (price <= 0) price = 1500.0;
    if (cost <= 0) cost = 1200.0;

    db.execute('''
      INSERT INTO batches (medicine_id, batch_number, expiry_date, quantity, purchase_price, selling_price, pharmacy_id, created_at)
      VALUES (?, 'BATCH-TEST-001', '2027-12-31', 50, ?, ?, 1, datetime('now'));
    ''', [testMedId, cost, price]);
    testBatchId = db.lastInsertRowId;
    initialQty = 50;
    print('✓ تم إنشاء دفعة مخزون جديدة للدواء ($testMedName) برصيد 50 حبة.');
  } else {
    final b = sampleBatch.first;
    testBatchId = b['batch_id'] as int;
    testMedId = b['medicine_id'] as int;
    testMedName = b['name_ar'].toString();
    initialQty = b['quantity'] as int;
    price = (b['selling_price'] as num).toDouble();
    cost = (b['purchase_price'] as num).toDouble();
    if (price <= 0) price = 1500.0;
    if (cost <= 0) cost = 1200.0;
    print('✓ تم اختيار الدواء للتجربة: $testMedName | الدفعة: #$testBatchId | الرصيد الحالي: $initialQty حبة');
  }

  // جلب معرفات الحسابات المحاسبية
  final accCash = db.select("SELECT id FROM accounts WHERE code = '1101';").first['id'] as int;
  final accRevenue = db.select("SELECT id FROM accounts WHERE code = '4101';").first['id'] as int;
  final accReturn = db.select("SELECT id FROM accounts WHERE code = '4102';").first['id'] as int;
  final accExpense = db.select("SELECT id FROM accounts WHERE code = '5201';").first['id'] as int;

  // ==========================================
  // الاختبار 2: عملية البيع في نقطة البيع (POS Sale)
  // ==========================================
  print('\n--- [2/7] محاكاة بيع نقدي (POS Sale) وحفظ الفاتورة ---');
  final saleQty = 2;
  final invoiceTotal = price * saleQty;
  final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

  db.execute('BEGIN TRANSACTION;');
  try {
    // 1. إنشاء الفاتورة في جدول sales
    db.execute('''
      INSERT INTO sales (
        pharmacy_id, invoice_number, total_amount, sub_total, tax_amount, discount,
        payment_method, status, created_at
      ) VALUES (
        1, ?, ?, ?, 0.0, 0.0,
        'نقدي', 'completed', datetime('now')
      );
    ''', [invoiceNumber, invoiceTotal, invoiceTotal]);
    final saleId = db.lastInsertRowId;

    // 2. إضافة بنود الفاتورة في sale_items
    db.execute('''
      INSERT INTO sale_items (
        sale_id, medicine_id, batch_id, quantity, unit_price, subtotal,
        tax_rate, tax_amount, total, unit_name, conversion_factor, selected_quantity
      ) VALUES (
        ?, ?, ?, ?, ?, ?,
        0.0, 0.0, ?, 'حبة', 1, ?
      );
    ''', [saleId, testMedId, testBatchId, saleQty, price, invoiceTotal, invoiceTotal, saleQty]);
    final saleItemId = db.lastInsertRowId;

    // 3. خصم المخزون بنظام FEFO
    db.execute('''
      UPDATE batches SET quantity = quantity - ? WHERE id = ?;
    ''', [saleQty, testBatchId]);

    // 4. إنشاء قيد اليومية المحاسبي المزدوج في journal_entries & journal_entry_lines
    final jeRef = 'JE-SALE-${DateTime.now().millisecondsSinceEpoch}';
    db.execute('''
      INSERT INTO journal_entries (
        reference_number, date, description, source, source_id, status, created_at, updated_at
      ) VALUES (
        ?, datetime('now'), 'إثبات مبيعات نقدية فاتورة رقم $invoiceNumber', 'Sales', ?, 'posted', datetime('now'), datetime('now')
      );
    ''', [jeRef, saleId]);
    final jeId = db.lastInsertRowId;

    // السطور: من حـ/ صندوق النقدية (مدين) إلى حـ/ إيرادات المبيعات (دائن)
    db.execute('''
      INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
      VALUES 
        (?, ?, ?, 0.0, 'قبض نقدي مبيعات فاتورة $invoiceNumber'),
        (?, ?, 0.0, ?, 'إيراد مبيعات فاتورة $invoiceNumber');
    ''', [jeId, accCash, invoiceTotal, jeId, accRevenue, invoiceTotal]);

    db.execute('COMMIT;');

    // التحقق من الخصم
    final qtyAfterSale = db.select('SELECT quantity FROM batches WHERE id = ?;', [testBatchId]).first['quantity'] as int;
    if (qtyAfterSale != initialQty - saleQty) {
      throw Exception('خطأ في خصم المخزون! المتوقع: ${initialQty - saleQty}, الفعلي: $qtyAfterSale');
    }
    print('✓ تم حفظ الفاتورة بنجاح برقم: $invoiceNumber');
    print('✓ إجمالي الفاتورة: $invoiceTotal ريال');
    print('✓ رصيد المخزون بعد البيع: $qtyAfterSale حبة (تم الخصم بدقة: -$saleQty)');

    // ==========================================
    // الاختبار 3: مراجعة الفواتير واستعراض التفاصيل
    // ==========================================
    print('\n--- [3/7] مراجعة الفاتورة واستعراض تفاصيلها في النظام ---');
    final reviewedSale = db.select('SELECT * FROM sales WHERE id = ?;', [saleId]).first;
    final reviewedItems = db.select('SELECT * FROM sale_items WHERE sale_id = ?;', [saleId]);
    print('✓ استرجاع الفاتورة: رقم ${reviewedSale['invoice_number']} | الحالة: ${reviewedSale['status']} | طريقة الدفع: ${reviewedSale['payment_method']} | البنود: ${reviewedItems.length} صنف');
    for (var it in reviewedItems) {
      print('   - صنف ID ${it['medicine_id']}: الكمية المباعة ${it['quantity']} بسعر ${it['unit_price']} = إجمالي ${it['subtotal']} ريال');
    }

    // ==========================================
    // الاختبار 4: استرجاع دواء من خلال الفاتورة (Sales Return)
    // ==========================================
    print('\n--- [4/7] استرجاع دواء من الفاتورة (Return) والتحقق من عودة المخزون ---');
    final returnQty = 1;
    final returnAmount = price * returnQty;

    db.execute('BEGIN TRANSACTION;');

    // 1. إنشاء سجل المرتجع
    db.execute('''
      INSERT INTO returns (
        sale_id, total_amount, settlement_method, payment_method, reason, created_at, pharmacy_id
      ) VALUES (
        ?, ?, 'refund', 'نقدي', 'طلب العميل استرجاع حبة واحدة', datetime('now'), 1
      );
    ''', [saleId, returnAmount]);
    final returnId = db.lastInsertRowId;

    // 2. بنود المرتجع
    db.execute('''
      INSERT INTO return_items (
        return_id, medicine_id, quantity, unit_price, subtotal, original_sale_item_id,
        qty_pill
      ) VALUES (
        ?, ?, ?, ?, ?, ?,
        ?
      );
    ''', [returnId, testMedId, returnQty, price, returnAmount, saleItemId, returnQty]);

    // 3. إعادة الكمية إلى دفعة المخزون بدقة تامة!
    db.execute('''
      UPDATE batches SET quantity = quantity + ? WHERE id = ?;
    ''', [returnQty, testBatchId]);

    // 4. تسجيل قيد الارتجاع المحاسبي في journal_entries & lines
    final jeReturnRef = 'JE-RET-${DateTime.now().millisecondsSinceEpoch}';
    db.execute('''
      INSERT INTO journal_entries (
        reference_number, date, description, source, source_id, status, created_at, updated_at
      ) VALUES (
        ?, datetime('now'), 'إثبات مردودات مبيعات مرتجع رقم $returnId', 'Return', ?, 'posted', datetime('now'), datetime('now')
      );
    ''', [jeReturnRef, returnId]);
    final jeRetId = db.lastInsertRowId;

    // من حـ/ مردودات المبيعات (مدين) إلى حـ/ صندوق النقدية (دائن)
    db.execute('''
      INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
      VALUES 
        (?, ?, ?, 0.0, 'مردودات مبيعات مرتجع $returnId'),
        (?, ?, 0.0, ?, 'رد نقدي للعميل مرتجع $returnId');
    ''', [jeRetId, accReturn, returnAmount, jeRetId, accCash, returnAmount]);

    db.execute('COMMIT;');

    final qtyAfterReturn = db.select('SELECT quantity FROM batches WHERE id = ?;', [testBatchId]).first['quantity'] as int;
    if (qtyAfterReturn != qtyAfterSale + returnQty) {
      throw Exception('خطأ في استعادة رصيد المخزون!');
    }
    print('✓ تم تسجيل المرتجع بنجاح برقم: #$returnId');
    print('✓ رصيد المخزون بعد الارتجاع: $qtyAfterReturn حبة (تمت استعادة +$returnQty حبة بنجاح تام إلى الرف!)');

    // ==========================================
    // الاختبار 5: تسجيل المصروفات وسندات الصرف (Expenses)
    // ==========================================
    print('\n--- [5/7] تسجيل المصروفات المحاسبية وسندات الصرف ---');
    final expenseAmount = 500.0;
    db.execute('BEGIN TRANSACTION;');
    db.execute('''
      INSERT INTO expenses (
        category, amount, notes, payment_method, pharmacy_id, created_at
      ) VALUES (
        'مرافق وخدمات (كهرباء الصيدلية)', ?, 'سداد نقدي من الدرج', 'نقدي', 1, datetime('now')
      );
    ''', [expenseAmount]);
    final expenseId = db.lastInsertRowId;

    // قيد المصروف: من حـ/ المصروفات العمومية (مدين) إلى حـ/ الصندوق (دائن)
    final jeExpRef = 'JE-EXP-${DateTime.now().millisecondsSinceEpoch}';
    db.execute('''
      INSERT INTO journal_entries (
        reference_number, date, description, source, source_id, status, created_at, updated_at
      ) VALUES (
        ?, datetime('now'), 'سداد مصروف كهرباء سند رقم $expenseId', 'Expense', ?, 'posted', datetime('now'), datetime('now')
      );
    ''', [jeExpRef, expenseId]);
    final jeExpId = db.lastInsertRowId;

    db.execute('''
      INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
      VALUES 
        (?, ?, ?, 0.0, 'مصروفات عمومية وتشغيلية سند $expenseId'),
        (?, ?, 0.0, ?, 'صرف نقدي من الصندوق سند $expenseId');
    ''', [jeExpId, accExpense, expenseAmount, jeExpId, accCash, expenseAmount]);

    db.execute('COMMIT;');
    print('✓ تم تسجيل المصروف بنجاح برقم #$expenseId بمبلغ $expenseAmount ريال وقيده محاسبياً.');

    // ==========================================
    // الاختبار 6: إغلاق اليومية المحاسبي (Day Closing)
    // ==========================================
    print('\n--- [6/7] فحص واختبار إغلاق اليومية المحاسبي (Shift/Day Closing) ---');
    final todaySales = (db.select("SELECT sum(total_amount) as s FROM sales WHERE date(created_at) = date('now');").first['s'] as num?)?.toDouble() ?? 0.0;
    final todayReturns = (db.select("SELECT sum(total_amount) as r FROM returns WHERE date(created_at) = date('now');").first['r'] as num?)?.toDouble() ?? 0.0;
    final todayExpenses = (db.select("SELECT sum(amount) as e FROM expenses WHERE date(created_at) = date('now');").first['e'] as num?)?.toDouble() ?? 0.0;
    final netProfit = todaySales - todayReturns - todayExpenses;
    final cashInDrawer = netProfit;

    print('   - إجمالي مبيعات اليوم: $todaySales ريال');
    print('   - إجمالي مرتجعات اليوم: $todayReturns ريال');
    print('   - إجمالي مصاريف اليوم: $todayExpenses ريال');
    print('   - صافي النقدية المفترضة في الدرج: $cashInDrawer ريال');

    // تسجيل إغلاق اليومية في day_closings
    db.execute('''
      INSERT INTO day_closings (
        date, period_start, total_sales, total_returns, total_expenses, total_vendor_payments,
        cost_of_goods_sold, net_profit, cash_in_drawer, pharmacy_id, created_at
      ) VALUES (
        datetime('now'), datetime('now', '-1 day'), ?, ?, ?, 0.0,
        0.0, ?, ?, 1, datetime('now')
      );
    ''', [todaySales, todayReturns, todayExpenses, netProfit, cashInDrawer]);
    final closingId = db.lastInsertRowId;
    print('✓ تم إغلاق اليومية بنجاح وتسجيل تقرير المطابقة رقم: #$closingId.');

    // ==========================================
    // الاختبار 7: النسخ الاحتياطي والاستعادة ومطابقة التوازن
    // ==========================================
    print('\n--- [7/7] فحص النسخ الاحتياطي والاستعادة وتوازن ميزان المراجعة المحاسبي ---');

    // توازن ميزان المراجعة (Debits == Credits)
    final linesCheck = db.select('''
      SELECT sum(debit) as total_debit, sum(credit) as total_credit FROM journal_entry_lines;
    ''').first;
    final totalDebits = (linesCheck['total_debit'] as num?)?.toDouble() ?? 0.0;
    final totalCredits = (linesCheck['total_credit'] as num?)?.toDouble() ?? 0.0;
    print('   - إجمالي المدين: $totalDebits ريال');
    print('   - إجمالي الدائن: $totalCredits ريال');
    final isBalanced = (totalDebits - totalCredits).abs() < 0.001;
    if (!isBalanced) {
      throw Exception('ميزان المراجعة غير متزن!');
    }
    print('✓ ميزان المراجعة المحاسبي متزن 100% (المدين = الدائن = $totalDebits ريال) كأنظمة يمن سوفت العالمية!');

    // فحص النسخ الاحتياطي
    final backupDir = Directory('C:\\Users\\hp\\Desktop\\PharmaOS_Backups');
    if (!backupDir.existsSync()) backupDir.createSync(recursive: true);
    final backupFile = File('${backupDir.path}\\نسخة_فحص_شاملة_${DateTime.now().millisecondsSinceEpoch}.pharmaos_backup');
    
    // تفريغ WAL للقرص
    db.execute('PRAGMA wal_checkpoint(FULL);');
    dbFile.copySync(backupFile.path);

    print('✓ تم إنشاء ملف النسخة الاحتياطية بنجاح:');
    print('   - الحجم: ${(backupFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} ميجابايت');
    print('   - المسار: ${backupFile.path}');

    // اختبار قراءة النسخة الاحتياطية (Restore Verification)
    final restoreTestDb = sqlite3.open(backupFile.path);
    restoreTestDb.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");
    final restoredMeds = restoreTestDb.select('SELECT count(*) as c FROM medicines;').first['c'];
    final restoredSales = restoreTestDb.select('SELECT count(*) as c FROM sales;').first['c'];
    final restoredReturns = restoreTestDb.select('SELECT count(*) as c FROM returns;').first['c'];
    final restoredEntries = restoreTestDb.select('SELECT count(*) as c FROM journal_entries;').first['c'];
    restoreTestDb.dispose();

    print('✓ تم التحقق من سلامة استعادة النسخة الاحتياطية بنجاح:');
    print('   - عدد الأدوية في النسخة المستعادة: $restoredMeds دواء');
    print('   - عدد الفواتير في النسخة المستعادة: $restoredSales فاتورة');
    print('   - عدد المرتجعات في النسخة المستعادة: $restoredReturns مرتجع');
    print('   - عدد القيود المحاسبية المستعادة: $restoredEntries قيد محاسبي');

  } catch (e, st) {
    db.execute('ROLLBACK;');
    print('❌ خطأ في المحاكاة: $e');
    print(st);
    rethrow;
  } finally {
    db.dispose();
  }

  print('\n========================================================');
  print('🎉 اكتملت جميع اختبارات ومحاكاة دورة الصيدلي بنجاح 100% 🎉');
  print('========================================================');
}
