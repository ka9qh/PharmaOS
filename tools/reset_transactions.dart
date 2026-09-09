import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

void main() async {
  // للوصول إلى قاعدة البيانات في بيئة التطوير
  // في ويندوز، getApplicationSupportDirectory تكون عادة في AppData/Roaming
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
    print('⚠️ تحذير: لم يتم العثور على قاعدة البيانات في المسارات الافتراضية.');
    print('يرجى تشغيل البرنامج مرة واحدة على الأقل لإنشاء قاعدة البيانات.');
    return;
  } else {
    print('✅ تم العثور على قاعدة البيانات في: $dbPath');
  }

  // استخدمنا sqlite3 مباشرة بدلاً من drift لسهولة التنفيذ كسكربت خارجي
  final db = sqlite3.open(dbPath);
  
  print('🚀 جاري تصفير قاعدة البيانات من الحركات المالية والمخزنية...');
  
  try {
    // إيقاف قيود المفاتيح الأجنبية مؤقتاً لتجنب مشاكل الحذف
    db.execute('PRAGMA foreign_keys = OFF;');

    final tablesToClear = [
      'sales',
      'sale_items',
      'purchases',
      'purchase_items',
      'batches',
      'vendor_payments',
      'expenses',
      'returns',
      'return_items',
      'day_closings',
      'customer_payments',
      'cash_register_shifts',
      'cash_register_transactions',
      'inventory_write_offs',
      'needed_items',
      'audit_logs',
      'invoices',
      'worker_attendance'
    ];

    for (final table in tablesToClear) {
      try {
        db.execute('DELETE FROM $table;');
        // تصفير عداد الـ Auto Increment
        db.execute("UPDATE sqlite_sequence SET seq = 0 WHERE name = '$table';");
        print(' - تم تصفير جدول: $table');
      } catch (e) {
        print('   ⚠️ تخطي جدول $table (قد لا يكون موجوداً أو هناك خطأ): $e');
      }
    }

    db.execute('PRAGMA foreign_keys = ON;');
    print('🎉 تمت عملية التصفير بنجاح! النظام الآن نظيف ويحتوي فقط على الأدوية والشركات والتصنيفات والاعدادات.');
  } catch (e) {
    print('❌ حدث خطأ أثناء التصفير: $e');
  } finally {
    db.dispose();
  }
}
