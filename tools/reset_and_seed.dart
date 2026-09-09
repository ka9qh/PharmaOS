import 'package:flutter/widgets.dart';
import 'package:pharmaos/core/di/service_locator.dart';
import 'package:pharmaos/core/database/app_database.dart';
import 'package:pharmaos/core/services/database_seeder_service.dart';
import 'package:pharmaos/features/accounting/domain/repositories/general_ledger_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  
  final db = sl<AppDatabase>();
  print('Clearing existing tables...');
  
  // Wipe incomplete medicines & accounting
  await db.delete(db.medicines).go();
  await db.delete(db.journalEntryLines).go();
  await db.delete(db.journalEntries).go();
  await db.delete(db.accounts).go();
  
  print('Tables cleared. Starting seeding...');
  
  final seeder = sl<DatabaseSeederService>();
  final startTime = DateTime.now();
  await seeder.seedDatabaseIfEmpty();
  
  print('Medicines seeding took ${DateTime.now().difference(startTime).inSeconds} seconds');
  
  final glRepo = sl<GeneralLedgerRepository>();
  await glRepo.seedDefaultAccountsIfEmpty();
  
  print('Accounting seeding done.');
  
  final medsCount = await db.select(db.medicines).get();
  print('Total medicines in DB: ${medsCount.length}');
  
  final accountsCount = await db.select(db.accounts).get();
  print('Total accounts in DB: ${accountsCount.length}');
  
  print('Reset and seed completed successfully!');
}
