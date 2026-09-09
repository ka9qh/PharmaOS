class AccountingController {
  AccountingController._();

  static String? validatePaymentAmount(String text, double remainingDebt) {
    final value = double.tryParse(text);
    if (value == null || value <= 0) return 'مبلغ غير صالح';
    if (value > remainingDebt) return 'المبلغ أكبر من المتبقي على هذا المورد';
    return null;
  }
}
