import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'C:\\Users\\hp\\AppData\\Roaming\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  // 1. Total medicines
  final medCount = db.select('SELECT COUNT(*) as c FROM medicines;').first['c'];
  print('✅ إجمالي الأدوية في قاعدة البيانات: $medCount دواء');

  // 2. Classifications
  final typeCounts = db.select('SELECT medicine_type, COUNT(*) as c FROM medicines GROUP BY medicine_type;');
  for (final r in typeCounts) {
    final typeId = r['medicine_type'];
    final count = r['c'];
    final typeName = switch (typeId) {
      1 => 'حبوب وأقراص (Tablets)',
      2 => 'إبر وأمبولات (Injections/Ampoules)',
      3 => 'علب وزجاج ومغذيات (Bottles/Fluids)',
      4 => 'فراشات وشرنجات (Syringes/Butterflies)',
      _ => 'أخرى ($typeId)',
    };
    print('   🔹 $typeName: $count صنف');
  }

  // 3. Categories
  final catCount = db.select('SELECT COUNT(*) as c FROM categories;').first['c'];
  print('✅ إجمالي التصنيفات: $catCount');

  // 4. Companies
  final compCount = db.select('SELECT COUNT(*) as c FROM companies;').first['c'];
  print('✅ إجمالي الشركات المصنعة: $compCount');

  // 5. Suppliers
  final suppCount = db.select('SELECT COUNT(*) as c FROM suppliers;').first['c'];
  print('✅ إجمالي الموردين: $suppCount');

  // 6. Day closings
  final closingsCount = db.select('SELECT COUNT(*) as c FROM day_closings;').first['c'];
  print('✅ إجمالي سجلات إغلاق اليوميات: $closingsCount');

  // 7. Verify NO text dates exist in integer datetime columns
  final badMeds = db.select("SELECT COUNT(*) as c FROM medicines WHERE typeof(created_at) = 'text' OR typeof(updated_at) = 'text';").first['c'];
  final badCats = db.select("SELECT COUNT(*) as c FROM categories WHERE typeof(created_at) = 'text';").first['c'];
  final badComps = db.select("SELECT COUNT(*) as c FROM companies WHERE typeof(created_at) = 'text';").first['c'];
  final badClosings = db.select("SELECT COUNT(*) as c FROM day_closings WHERE typeof(created_at) = 'text' OR typeof(date) = 'text';").first['c'];

  print('--- فحص سلامة التواريخ المحاسبية والـ Radix-10 ---');
  print('   أخطاء تواريخ الأدوية: $badMeds');
  print('   أخطاء تواريخ التصنيفات: $badCats');
  print('   أخطاء تواريخ الشركات: $badComps');
  print('   أخطاء تواريخ الإغلاقات: $badClosings');

  if (badMeds == 0 && badCats == 0 && badComps == 0 && badClosings == 0) {
    print('🎉 تم القضاء على خطأ FormatException: Invalid radix-10 number بالكامل 100%!');
  }

  db.dispose();
}
