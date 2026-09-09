import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaos/core/di/service_locator.dart';
import 'package:pharmaos/features/accounting/domain/repositories/general_ledger_repository.dart';

void main() {
  testWidgets('Test GL entries', (tester) async {
    await setupServiceLocator();
    final glRepo = sl<GeneralLedgerRepository>();
    final entries = await glRepo.getJournalEntries();
    print('Fetched ${entries.length} entries successfully.');
  });
}
