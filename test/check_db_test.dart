import 'package:drift/drift.dart';
import 'package:pharmaos/core/di/service_locator.dart';
import 'package:pharmaos/core/database/app_database.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  
  final db = sl<AppDatabase>();
  final allMedicines = await db.select(db.medicines).get();
  print('Total medicines: ${allMedicines.length}');
  
  if (allMedicines.isNotEmpty) {
    print('First medicine is_active: ${allMedicines.first.isActive}');
  }
}
