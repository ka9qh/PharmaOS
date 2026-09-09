import '../../../../core/database/app_database.dart';
import '../../domain/entities/reports_entity.dart';

extension DayClosingRowMapper on DayClosingRow {
  DayClosingRecordEntity toEntity() => DayClosingRecordEntity(
        id: id,
        date: date,
        periodStart: periodStart,
        createdAt: createdAt,
        totalSales: totalSales,
        totalReturns: totalReturns,
        totalExpenses: totalExpenses,
        totalVendorPayments: totalVendorPayments,
        costOfGoodsSold: costOfGoodsSold,
        netProfit: netProfit,
        cashInDrawer: cashInDrawer,
        reportPdfPath: reportPdfPath,
        reportExcelPath: reportExcelPath,
        backupPath: backupPath,
      );
}
