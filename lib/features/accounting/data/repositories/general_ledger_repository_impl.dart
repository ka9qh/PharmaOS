import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/accounting_entities.dart';
import '../../domain/repositories/general_ledger_repository.dart';

class GeneralLedgerRepositoryImpl implements GeneralLedgerRepository {
  final AppDatabase _db;

  GeneralLedgerRepositoryImpl(this._db);

  @override
  Future<List<AccountEntity>> getAllAccounts() async {
    final rows = await _db.select(_db.accounts).get();
    return rows.map((r) => AccountEntity(
      id: r.id,
      code: r.code,
      name: r.name,
      type: r.type,
      parentId: r.parentId,
      isHeader: r.isHeader,
      balance: r.balance,
      isSystemAccount: r.isSystemAccount,
    )).toList();
  }

  @override
  Future<AccountEntity?> getAccount(int id) async {
    final row = await (_db.select(_db.accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return AccountEntity(
      id: row.id,
      code: row.code,
      name: row.name,
      type: row.type,
      parentId: row.parentId,
      isHeader: row.isHeader,
      balance: row.balance,
      isSystemAccount: row.isSystemAccount,
    );
  }

  @override
  Future<int?> getAccountIdByCode(String code) async {
    final row = await (_db.select(_db.accounts)..where((a) => a.code.equals(code))).getSingleOrNull();
    return row?.id;
  }

  @override
  Future<int> addAccount({
    required String code,
    required String name,
    required String type,
    int? parentId,
    bool isHeader = false,
  }) async {
    return await _db.into(_db.accounts).insert(AccountsCompanion.insert(
      code: code,
      name: name,
      type: type,
      parentId: Value(parentId),
      isHeader: Value(isHeader),
      isSystemAccount: const Value(false),
    ));
  }

  Future<int> _ensureAccount({
    required String code,
    required String name,
    required String type,
    int? parentId,
    bool isHeader = false,
  }) async {
    final existing = await (_db.select(_db.accounts)..where((a) => a.code.equals(code))).getSingleOrNull();
    if (existing != null) return existing.id;

    return await _db.into(_db.accounts).insert(AccountsCompanion.insert(
      code: code,
      name: name,
      type: type,
      parentId: Value(parentId),
      isHeader: Value(isHeader),
      isSystemAccount: const Value(true),
    ));
  }

  @override
  Future<void> seedDefaultAccountsIfEmpty() async {
    // الأصول (Assets)
    final assetsId = await _ensureAccount(
      code: '1', name: 'الأصول', type: 'Asset', isHeader: true,
    );
    
    final currentAssetsId = await _ensureAccount(
      code: '11', name: 'الأصول المتداولة', type: 'Asset', parentId: assetsId, isHeader: true,
    );
    
    await _ensureAccount(code: '1101', name: 'صندوق المعرض', type: 'Asset', parentId: currentAssetsId);
    await _ensureAccount(code: '1102', name: 'المخزون', type: 'Asset', parentId: currentAssetsId);
    await _ensureAccount(code: '1103', name: 'العملاء (الذمم المدينة)', type: 'Asset', parentId: currentAssetsId);

    // الخصوم (Liabilities)
    final liabilitiesId = await _ensureAccount(
      code: '2', name: 'الخصوم', type: 'Liability', isHeader: true,
    );
    
    final currentLiabilitiesId = await _ensureAccount(
      code: '21', name: 'الخصوم المتداولة', type: 'Liability', parentId: liabilitiesId, isHeader: true,
    );

    await _ensureAccount(code: '2101', name: 'الموردين (الذمم الدائنة)', type: 'Liability', parentId: currentLiabilitiesId);

    // الإيرادات (Revenues)
    final revenuesId = await _ensureAccount(
      code: '4', name: 'الإيرادات', type: 'Revenue', isHeader: true,
    );
    
    await _ensureAccount(code: '4101', name: 'إيرادات المبيعات', type: 'Revenue', parentId: revenuesId);
    await _ensureAccount(code: '4102', name: 'مردودات المبيعات', type: 'Revenue', parentId: revenuesId);

    // المصروفات (Expenses)
    final expensesId = await _ensureAccount(
      code: '5', name: 'المصروفات', type: 'Expense', isHeader: true,
    );
      
    await _ensureAccount(code: '5101', name: 'تكلفة البضاعة المباعة', type: 'Expense', parentId: expensesId);
    await _ensureAccount(code: '5201', name: 'مصروفات تشغيلية عامة', type: 'Expense', parentId: expensesId);
  }

  @override
  Future<int> postJournalEntry({
    required String referenceNumber,
    required DateTime date,
    required String description,
    required String source,
    int? sourceId,
    int? createdBy,
    required List<JournalEntryLineEntity> lines,
  }) async {
    final jeId = await _db.into(_db.journalEntries).insert(JournalEntriesCompanion.insert(
      referenceNumber: referenceNumber,
      date: date,
      description: description,
      source: Value(source),
      sourceId: Value(sourceId),
      createdBy: Value(createdBy),
    ));

      for (var line in lines) {
        await _db.into(_db.journalEntryLines).insert(JournalEntryLinesCompanion.insert(
          journalEntryId: jeId,
          accountId: line.accountId,
          debit: Value(line.debit),
          credit: Value(line.credit),
          description: Value(line.description),
        ));

        // Update account balance summary
        final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(line.accountId))).getSingle();
        double newBalance = account.balance;
        if (account.type == 'Asset' || account.type == 'Expense') {
          newBalance = newBalance + line.debit - line.credit;
        } else {
          newBalance = newBalance + line.credit - line.debit;
        }
        await (_db.update(_db.accounts)..where((a) => a.id.equals(line.accountId)))
            .write(AccountsCompanion(balance: Value(newBalance)));
      }

    return jeId;
  }

  @override
  Future<List<JournalEntryEntity>> getJournalEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? source,
    int? accountId,
  }) async {
    var query = _db.select(_db.journalEntries);
    if (startDate != null && endDate != null) {
      query.where((t) => t.date.isBetweenValues(startDate, endDate));
    }
    if (source != null) {
      query.where((t) => t.source.equals(source));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]);

    final entries = await query.get();
    List<JournalEntryEntity> result = [];

    for (var entry in entries) {
      // إحضار السطور لكل قيد
      var linesQuery = _db.select(_db.journalEntryLines).join([
        innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.journalEntryLines.accountId)),
      ])..where(_db.journalEntryLines.journalEntryId.equals(entry.id));

      final linesRows = await linesQuery.get();
      final lines = linesRows.map((row) {
        final line = row.readTable(_db.journalEntryLines);
        final acc = row.readTable(_db.accounts);
        return JournalEntryLineEntity(
          id: line.id,
          journalEntryId: line.journalEntryId,
          accountId: line.accountId,
          accountName: acc.name,
          debit: line.debit,
          credit: line.credit,
          description: line.description,
        );
      }).toList();

      // تصفية حسب accountId إن وُجد
      if (accountId == null || lines.any((l) => l.accountId == accountId)) {
        result.add(JournalEntryEntity(
          id: entry.id,
          referenceNumber: entry.referenceNumber,
          date: entry.date,
          description: entry.description,
          source: entry.source,
          sourceId: entry.sourceId,
          status: entry.status,
          createdBy: entry.createdBy,
          lines: lines,
        ));
      }
    }
    return result;
  }

  @override
  Future<bool> deleteJournalEntry(int id) async {
    return await _db.transaction(() async {
      final lines = await (_db.select(_db.journalEntryLines)..where((l) => l.journalEntryId.equals(id))).get();
      for (var line in lines) {
        final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(line.accountId))).getSingle();
        double newBalance = account.balance;
        // عكس القيد لحذف تأثيره
        if (account.type == 'Asset' || account.type == 'Expense') {
          newBalance = newBalance - line.debit + line.credit;
        } else {
          newBalance = newBalance - line.credit + line.debit;
        }
        await (_db.update(_db.accounts)..where((a) => a.id.equals(line.accountId)))
            .write(AccountsCompanion(balance: Value(newBalance)));
      }
      final count = await (_db.delete(_db.journalEntries)..where((j) => j.id.equals(id))).go();
      return count > 0;
    });
  }
}
