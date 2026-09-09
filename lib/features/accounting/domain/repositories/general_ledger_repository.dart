import '../entities/accounting_entities.dart';

abstract class GeneralLedgerRepository {
  /// جلب جميع الحسابات لتمثيل شجرة الحسابات
  Future<List<AccountEntity>> getAllAccounts();

  /// جلب تفاصيل حساب معين
  Future<AccountEntity?> getAccount(int id);

  /// جلب معرف الحساب بواسطة كوده
  Future<int?> getAccountIdByCode(String code);

  /// إضافة حساب جديد لشجرة الحسابات
  Future<int> addAccount({
    required String code,
    required String name,
    required String type,
    int? parentId,
    bool isHeader = false,
  });

  /// إنشاء القيد الافتتاحي والحسابات الافتراضية
  Future<void> seedDefaultAccountsIfEmpty();

  /// كتابة قيد يومية متكامل (رأس القيد + السطور)
  Future<int> postJournalEntry({
    required String referenceNumber,
    required DateTime date,
    required String description,
    required String source,
    int? sourceId,
    int? createdBy,
    required List<JournalEntryLineEntity> lines,
  });

  /// جلب القيود اليومية مع فلترة
  Future<List<JournalEntryEntity>> getJournalEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? source,
    int? accountId,
  });
  
  /// حذف قيد يومية بالكامل (عكس القيد أو حذفه حسب الصلاحيات)
  Future<bool> deleteJournalEntry(int id);
}
