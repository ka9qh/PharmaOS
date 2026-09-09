import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:pharmaos/core/di/service_locator.dart';
import 'package:pharmaos/features/accounting/domain/repositories/general_ledger_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  
  final glRepo = sl<GeneralLedgerRepository>();
  print('Repository initialized. Fetching journal entries...');
  
  try {
    final entries = await glRepo.getJournalEntries();
    print('Fetched ${entries.length} entries successfully.');
    exit(0);
  } catch (e, st) {
    print('Error occurred: $e');
    print(st);
    exit(1);
  }
}
