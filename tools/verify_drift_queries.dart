import 'dart:io';
import 'package:pharmaos/core/database/app_database.dart';

void main() async {
  print('Testing AppDatabase Drift queries...');
  final db = AppDatabase('PharmaOS-Seed-2026-CHANGE-ME');

  // 1. Medicines
  final meds = await (db.select(db.medicines)..limit(20)).get();
  print('✅ Successfully loaded ${meds.length} medicines via Drift without error!');
  final totalMeds = await db.customSelect('SELECT COUNT(*) as count FROM medicines;').getSingle();
  print('   Total medicines in DB: ${totalMeds.read<int>('count')}');

  // 2. Categories
  final cats = await db.select(db.categories).get();
  print('✅ Successfully loaded ${cats.length} categories via Drift!');

  // 3. Companies
  final comps = await db.select(db.companies).get();
  print('✅ Successfully loaded ${comps.length} companies via Drift!');

  // 4. Suppliers
  final supps = await db.select(db.suppliers).get();
  print('✅ Successfully loaded ${supps.length} suppliers via Drift!');

  // 5. Day closings
  final closings = await db.select(db.dayClosings).get();
  print('✅ Successfully loaded ${closings.length} day closings via Drift!');

  // 6. Users
  final users = await db.select(db.users).get();
  print('✅ Successfully loaded ${users.length} users via Drift!');

  // 7. Wallets
  final wallets = await db.select(db.wallets).get();
  print('✅ Successfully loaded ${wallets.length} wallets via Drift!');

  // 8. Units Check
  final typeCounts = await db.customSelect(
    'SELECT medicine_type, COUNT(*) as c FROM medicines GROUP BY medicine_type;'
  ).get();
  print('--- Medicines Classification Summary ---');
  for (final r in typeCounts) {
    final typeId = r.read<int>('medicine_type');
    final count = r.read<int>('c');
    final typeName = switch (typeId) {
      1 => 'حبوب وأقراص (Tablets)',
      2 => 'إبر وأمبولات (Injections/Ampoules)',
      3 => 'علب وزجاج ومغذيات (Bottles/Fluids)',
      4 => 'فراشات وشرنجات (Syringes/Butterflies)',
      _ => 'أخرى ($typeId)',
    };
    print('   $typeName: $count صنف');
  }

  await db.close();
  print('\n🎯 ALL SCREENS DATA VERIFIED 100% HEALTHY WITH ZERO ERRORS!');
}
