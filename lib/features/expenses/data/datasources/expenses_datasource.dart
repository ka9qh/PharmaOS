import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../accounting/domain/repositories/general_ledger_repository.dart';
import '../../../accounting/domain/entities/accounting_entities.dart';
import '../../domain/entities/expenses_entity.dart';

abstract class ExpensesDataSource {
  Future<ExpenseEntity> create({
    required String category,
    required double amount,
    String? notes,
    int? workerId,
    String? customWorkerName,
    String? paymentMethod,
    int? walletId,
    int? recordedBy,
  });

  Future<List<ExpenseEntity>> listAll();
  Future<List<ExpenseEntity>> listToday();
  Future<List<ExpenseEntity>> listByDate(DateTime date);
  Future<List<ExpenseEntity>> listByMonth({required int year, required int month});
  Future<List<ExpenseEntity>> listByYear(int year);
  Future<List<ExpenseEntity>> listByDateRange({required DateTime from, required DateTime to});
  Future<double> getTodayTotal();
  Future<List<ExpenseEntity>> listByWorker(int workerId, {DateTime? from, DateTime? to});
}

class ExpensesDataSourceImpl implements ExpensesDataSource {
  final AppDatabase _db;
  final GeneralLedgerRepository _glRepo;
  ExpensesDataSourceImpl(this._db, this._glRepo);

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _baseQuery() {
    return _db.select(_db.expenses).join([
      leftOuterJoin(_db.workers, _db.workers.id.equalsExp(_db.expenses.workerId)),
      leftOuterJoin(_db.wallets, _db.wallets.id.equalsExp(_db.expenses.walletId)),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.expenses.recordedBy)),
    ]);
  }

  ExpenseEntity _mapRow(TypedResult row) {
    final exp = row.readTable(_db.expenses);
    final worker = row.readTableOrNull(_db.workers);
    final wallet = row.readTableOrNull(_db.wallets);
    final user = row.readTableOrNull(_db.users);

    final resolvedWorkerName = (exp.customWorkerName != null && exp.customWorkerName!.trim().isNotEmpty)
        ? exp.customWorkerName!.trim()
        : worker?.name;

    final recorderName = user?.fullName ?? user?.username;
    final walletName = wallet?.name;

    return ExpenseEntity(
      id: exp.id,
      category: exp.category,
      amount: exp.amount,
      notes: exp.notes,
      createdAt: exp.createdAt,
      paymentMethod: exp.paymentMethod,
      walletId: exp.walletId,
      walletName: walletName,
      workerId: exp.workerId,
      workerName: resolvedWorkerName,
      customWorkerName: exp.customWorkerName,
      recordedBy: exp.recordedBy,
      recorderName: recorderName,
    );
  }

  @override
  Future<ExpenseEntity> create({
    required String category,
    required double amount,
    String? notes,
    int? workerId,
    String? customWorkerName,
    String? paymentMethod,
    int? walletId,
    int? recordedBy,
  }) async {
    if (amount <= 0) {
      throw Exception('لا يمكن تسجيل مصروف بمبلغ سالب أو صفر');
    }

    return _db.transaction(() async {
      final id = await _db.into(_db.expenses).insert(
            ExpensesCompanion.insert(
              category: category,
              amount: amount,
              notes: Value(notes),
              workerId: Value(workerId),
              customWorkerName: Value(customWorkerName),
              paymentMethod: Value(paymentMethod ?? 'نقدي'),
              walletId: Value(walletId),
              recordedBy: Value(recordedBy),
            ),
          );
          
      final cashAccId = await _glRepo.getAccountIdByCode('1101');
      // For simplicity, we map all general expenses to code 5102 (General Expenses).
      final expenseAccId = await _glRepo.getAccountIdByCode('5102'); 
      
      if (cashAccId != null) {
        int? finalExpId = expenseAccId;
        if (finalExpId == null) {
          try {
            await _glRepo.addAccount(
              code: '5102', name: 'مصروفات عامة', type: 'expense', isHeader: false,
            );
            finalExpId = await _glRepo.getAccountIdByCode('5102');
          } catch (e) {
            // ignore
          }
        }
        
        if (finalExpId != null) {
          await _glRepo.postJournalEntry(
            referenceNumber: 'EXP-$id',
            date: DateTime.now(),
            description: 'تسجيل مصروف: $category',
            source: 'Expense',
            sourceId: id,
            createdBy: recordedBy ?? 1,
            lines: [
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0, accountId: finalExpId, accountName: '',
                debit: amount, credit: 0, description: notes ?? 'مصروف $category',
              ),
              JournalEntryLineEntity(
                id: 0, journalEntryId: 0, accountId: cashAccId, accountName: '',
                debit: 0, credit: amount, description: 'دفع مصروف',
              ),
            ],
          );
        }
      }

      final query = _baseQuery()..where(_db.expenses.id.equals(id));
      final single = await query.getSingle();
      return _mapRow(single);
    });
  }

  @override
  Future<List<ExpenseEntity>> listAll() async {
    final query = _baseQuery()
      ..orderBy([OrderingTerm.desc(_db.expenses.createdAt)]);
    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  @override
  Future<List<ExpenseEntity>> listToday() async {
    final query = _baseQuery()
      ..where(_db.expenses.createdAt.isBiggerOrEqualValue(_startOfToday))
      ..orderBy([OrderingTerm.desc(_db.expenses.createdAt)]);
    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  @override
  Future<List<ExpenseEntity>> listByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    final query = _baseQuery()
      ..where(_db.expenses.createdAt.isBiggerOrEqualValue(start) & _db.expenses.createdAt.isSmallerOrEqualValue(end))
      ..orderBy([OrderingTerm.desc(_db.expenses.createdAt)]);
    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  @override
  Future<List<ExpenseEntity>> listByMonth({required int year, required int month}) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(month == 12 ? year + 1 : year, month == 12 ? 1 : month + 1, 1);
    final query = _baseQuery()
      ..where(_db.expenses.createdAt.isBiggerOrEqualValue(start) & _db.expenses.createdAt.isSmallerThanValue(end))
      ..orderBy([OrderingTerm.desc(_db.expenses.createdAt)]);
    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  @override
  Future<List<ExpenseEntity>> listByYear(int year) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final query = _baseQuery()
      ..where(_db.expenses.createdAt.isBiggerOrEqualValue(start) & _db.expenses.createdAt.isSmallerThanValue(end))
      ..orderBy([OrderingTerm.desc(_db.expenses.createdAt)]);
    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  @override
  Future<List<ExpenseEntity>> listByDateRange({required DateTime from, required DateTime to}) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    final query = _baseQuery()
      ..where(_db.expenses.createdAt.isBiggerOrEqualValue(start) & _db.expenses.createdAt.isSmallerOrEqualValue(end))
      ..orderBy([OrderingTerm.desc(_db.expenses.createdAt)]);
    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  @override
  Future<double> getTodayTotal() async {
    final rows = await listToday();
    return rows.fold<double>(0, (sum, e) => sum + e.amount);
  }

  @override
  Future<List<ExpenseEntity>> listByWorker(int workerId, {DateTime? from, DateTime? to}) async {
    var query = _baseQuery()..where(_db.expenses.workerId.equals(workerId));
    if (from != null) {
      query = query..where(_db.expenses.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query = query..where(_db.expenses.createdAt.isSmallerOrEqualValue(to));
    }
    final rows = await (query..orderBy([OrderingTerm.desc(_db.expenses.createdAt)])).get();
    return rows.map(_mapRow).toList();
  }
}
