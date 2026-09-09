import 'package:drift/drift.dart';
import 'journal_entries_table.dart';
import 'accounts_table.dart';

@DataClassName('JournalEntryLineRow')
class JournalEntryLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // رقم القيد الأساسي
  IntColumn get journalEntryId => integer().references(JournalEntries, #id, onDelete: KeyAction.cascade)();
  
  // الحساب الذي تأثر بهذا السطر (مدين أو دائن)
  IntColumn get accountId => integer().references(Accounts, #id)();
  
  // المبلغ المدين (Debit)
  RealColumn get debit => real().withDefault(const Constant(0))();
  
  // المبلغ الدائن (Credit)
  RealColumn get credit => real().withDefault(const Constant(0))();
  
  // وصف أو بيان مخصص لهذا السطر (مثل: إثبات ضريبة، إثبات خصم..)
  TextColumn get description => text().nullable()();
}
