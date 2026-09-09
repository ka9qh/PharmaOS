class AccountEntity {
  final int id;
  final String code;
  final String name;
  final String type; // Asset, Liability, Equity, Revenue, Expense
  final int? parentId;
  final bool isHeader;
  final double balance;
  final bool isSystemAccount;

  const AccountEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    required this.isHeader,
    required this.balance,
    required this.isSystemAccount,
  });
}

class JournalEntryEntity {
  final int id;
  final String referenceNumber;
  final DateTime date;
  final String description;
  final String source;
  final int? sourceId;
  final String status;
  final int? createdBy;
  final List<JournalEntryLineEntity> lines;

  const JournalEntryEntity({
    required this.id,
    required this.referenceNumber,
    required this.date,
    required this.description,
    required this.source,
    this.sourceId,
    required this.status,
    this.createdBy,
    required this.lines,
  });
}

class JournalEntryLineEntity {
  final int id;
  final int journalEntryId;
  final int accountId;
  final String accountName;
  final double debit;
  final double credit;
  final String? description;

  const JournalEntryLineEntity({
    required this.id,
    required this.journalEntryId,
    required this.accountId,
    required this.accountName,
    required this.debit,
    required this.credit,
    this.description,
  });
}
