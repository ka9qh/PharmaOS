export '../../../../core/services/day_closing_service.dart'
    show DayClosingSummary, DayClosingResult;

class DayClosingRecordEntity {
  final int id;
  final DateTime date;
  final DateTime periodStart;
  final DateTime createdAt; // نهاية الفترة فعليًا (وقت الضغط على زر الإغلاق)
  final double totalSales;
  final double totalReturns;
  final double totalExpenses;
  final double totalVendorPayments;
  final double costOfGoodsSold;
  final double netProfit;
  final double cashInDrawer;
  final String? reportPdfPath;
  final String? reportExcelPath;
  final String? backupPath;

  const DayClosingRecordEntity({
    required this.id,
    required this.date,
    required this.periodStart,
    required this.createdAt,
    required this.totalSales,
    required this.totalReturns,
    required this.totalExpenses,
    required this.totalVendorPayments,
    required this.costOfGoodsSold,
    required this.netProfit,
    required this.cashInDrawer,
    this.reportPdfPath,
    this.reportExcelPath,
    this.backupPath,
  });
}
