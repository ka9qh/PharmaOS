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

  print('✅ تم العثور على قاعدة البيانات في: $dbPath');
  
  final db = sqlite3.open(dbPath);
  
  try {
    db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");
    
    // اختبار بسيط للتأكد من فك التشفير
    db.select('SELECT count(*) FROM medicines;');
    
    print('🔄 جاري بدء عملية تصفير البيانات...');
    
    db.execute('BEGIN TRANSACTION;');
    
    // مسح بيانات الحركات المالية والمخزنية
    final tablesToClear = [
      'sale_items',
      'sales',
      'purchase_items',
      'purchases',
      'return_items',
      'returns',
      'inventory_write_offs',
      'batches',
      'journal_entry_lines',
      'journal_entries',
      'payroll',
      'worker_advances',
      'worker_attendance',
      'cash_register_transactions',
      'wallet_transactions',
      'insurance_policies'
    ];
    
    for (final table in tablesToClear) {
      try {
        db.execute('DELETE FROM $table;');
        // تصفير العداد التلقائي
        db.execute("DELETE FROM sqlite_sequence WHERE name='$table';");
        print(' - تم تصفير جدول $table');
      } catch (e) {
        print(' - تخطي جدول $table (قد لا يكون موجوداً)');
      }
    }
    
    // مسح ديون العملاء
    db.execute('UPDATE customers SET balance = 0;');
    
    // مسح أرصدة الموردين
    db.execute('UPDATE suppliers SET balance = 0;');
    
    // مسح أرصدة الحسابات المالية (إرجاعها للصفر)
    db.execute('UPDATE accounting_accounts SET balance = 0;');
    
    db.execute('COMMIT;');
    
    print('🎉 تمت عملية التصفير بنجاح!');
    print('النظام الآن جاهز كنظام جديد تماماً، مع الاحتفاظ بـ:');
    print('- الأدوية (الأسماء العلمية والباركودات)');
    print('- الموردين والشركات');
    print('- شجرة الحسابات الأساسية');
    print('- إعدادات النظام');
    print('- حسابات المستخدمين (المدير)');
    
  } catch (e) {
    db.execute('ROLLBACK;');
    print('❌ حدث خطأ أثناء التصفير: $e');
  } finally {
    db.dispose();
  }
}
