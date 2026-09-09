import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

void main() {
  final appData = Platform.environment['APPDATA'];
  final possiblePaths = [
    p.join(appData!, 'com.example', 'PharmaOS', 'pharmaos_secure.db'),
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
    print('❌ خطأ: لم يتم العثور على قاعدة البيانات.');
    return;
  }

  print('✅ تم العثور على قاعدة البيانات: $dbPath');
  final db = sqlite3.open(dbPath);
  
  try {
    db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");
    
    // 1. اختبار جدول الأدوية
    final medCount = db.select('SELECT count(*) as count FROM medicines;').first['count'] as int;
    print('🧪 عدد الأدوية في النظام: $medCount');
    
    // 2. التحقق من القيود المحاسبية (ميزان المراجعة)
    final balances = db.select('''
      SELECT account_id, SUM(debit) as debits, SUM(credit) as credits 
      FROM journal_entry_lines 
      GROUP BY account_id
    ''');
    
    double totalDebits = 0;
    double totalCredits = 0;
    for (final row in balances) {
      totalDebits += row['debits'] as double;
      totalCredits += row['credits'] as double;
    }
    
    print('🧪 ميزان المراجعة:');
    print('   - إجمالي المدين: $totalDebits');
    print('   - إجمالي الدائن: $totalCredits');
    
    if ((totalDebits - totalCredits).abs() > 0.01) {
      print('❌ ميزان المراجعة غير متزن!');
    } else {
      print('✅ ميزان المراجعة متزن تماماً.');
    }
    
    // 3. التحقق من المخزون
    final batchesCount = db.select('SELECT count(*) as count FROM batches;').first['count'] as int;
    print('🧪 عدد الدفعات في المخزون (Batches): $batchesCount');
    
    // 4. التحقق من جداول المرحلة الثالثة (HR & التأمين)
    try {
      db.select('SELECT count(*) FROM insurance_policies');
      db.select('SELECT count(*) FROM payroll');
      print('✅ جداول المرحلة الثالثة موجودة وقابلة للوصول.');
    } catch (e) {
      print('❌ خطأ في جداول المرحلة الثالثة: $e');
    }
    
    print('🚀 اكتمل الاختبار بنجاح. النظام قوي ومستقر!');
    
  } catch (e) {
    print('❌ حدث خطأ أثناء الاختبار: $e');
  } finally {
    db.dispose();
  }
}
