import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaos/core/di/service_locator.dart';
import 'package:pharmaos/core/database/app_database.dart';
import 'package:pharmaos/features/suppliers/data/datasources/supplier_ledger_datasource.dart';
import 'package:pharmaos/features/suppliers/domain/repositories/suppliers_repository.dart';

import 'package:drift/native.dart';

void main() {
  test('Verify SupplierLedgerDataSource registration and query', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final ledgerDs = SupplierLedgerDataSource(db);

    final entries = await ledgerDs.getSupplierLedger(1);
    expect(entries, isNotNull);
    expect(entries, isEmpty);

    await db.close();
  });
}
