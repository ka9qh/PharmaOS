class LedgerEntryEntity {
  final DateTime date;
  final String description; // نوع الحركة: فاتورة مبيعات، دفعة نقدية، مرتجع
  final String referenceNumber; // رقم الفاتورة أو السند
  final double debit; // مدين (عليه)
  final double credit; // دائن (له)
  final double balance; // الرصيد التراكمي

  const LedgerEntryEntity({
    required this.date,
    required this.description,
    required this.referenceNumber,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  LedgerEntryEntity copyWith({
    DateTime? date,
    String? description,
    String? referenceNumber,
    double? debit,
    double? credit,
    double? balance,
  }) {
    return LedgerEntryEntity(
      date: date ?? this.date,
      description: description ?? this.description,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      balance: balance ?? this.balance,
    );
  }
}
