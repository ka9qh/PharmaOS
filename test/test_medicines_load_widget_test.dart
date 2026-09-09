import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaos/core/database/app_database.dart';
import 'package:pharmaos/core/di/service_locator.dart';
import 'package:pharmaos/features/medicines/domain/usecases/medicines_usecase.dart';
import 'package:pharmaos/features/medicines/domain/repositories/medicines_repository.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('Test Medicines Load', (WidgetTester tester) async {
    print('Testing direct repository call on in-memory DB...');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    
    // Test if a simple query throws
    try {
      final query = db.select(db.medicines)..where((m) => m.isActive.equals(true));
      final rows = await query.get();
      print('Query successful! Rows: ${rows.length}');
    } catch(e, st) {
      print('Query failed!');
      print(e);
      print(st);
    }
  });
}
