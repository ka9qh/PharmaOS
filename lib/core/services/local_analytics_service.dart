// التحليلات المحلية القائمة على القواعد (Rule-Based) - راجع docs/AI_DEVELOPMENT_GUIDE.md
// كل الحسابات هنا رياضية/استعلامية بحتة، دون أي اعتماد على نموذج ذكاء اصطناعي
// توليدي أو اتصال إنترنت. المبدأ: الأرقام المالية تُحسب بمعادلات صريحة دائمًا.

import 'package:drift/drift.dart';
import '../database/app_database.dart';

class TopSellingMedicine {
  final int medicineId;
  final String medicineName;
  final int totalQuantitySold;
  final double totalRevenue;

  const TopSellingMedicine({
    required this.medicineId,
    required this.medicineName,
    required this.totalQuantitySold,
    required this.totalRevenue,
  });
}

class SalesTrend {
  final double currentPeriodTotal;
  final double previousPeriodTotal;

  const SalesTrend({required this.currentPeriodTotal, required this.previousPeriodTotal});

  /// null إذا لم تكن هناك مبيعات في الفترة السابقة أصلًا (لا يوجد أساس للمقارنة)
  double? get percentChange {
    if (previousPeriodTotal == 0) return null;
    return ((currentPeriodTotal - previousPeriodTotal) / previousPeriodTotal) * 100;
  }

  bool get isUp => percentChange != null && percentChange! >= 0;
}

class ExpiringBatchInfo {
  final int batchId;
  final int medicineId;
  final String medicineName;
  final DateTime expiryDate;
  final int quantity;

  const ExpiringBatchInfo({
    required this.batchId,
    required this.medicineId,
    required this.medicineName,
    required this.expiryDate,
    required this.quantity,
  });

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
  bool get isAlreadyExpired => daysUntilExpiry < 0;
}

class LocalAnalyticsService {
  final AppDatabase _db;
  LocalAnalyticsService(this._db);

  /// أكثر الأدوية مبيعًا خلال آخر [days] يومًا (افتراضيًا 30)
  Future<List<TopSellingMedicine>> getTopSellingMedicines({int limit = 5, int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _db.customSelect(
      'SELECT si.medicine_id AS medicine_id, m.name_ar AS name_ar, '
      'SUM(si.quantity) AS total_qty, SUM(si.subtotal) AS total_revenue '
      'FROM sale_items si '
      'JOIN sales s ON s.id = si.sale_id '
      'JOIN medicines m ON m.id = si.medicine_id '
      'WHERE s.created_at >= ? '
      'GROUP BY si.medicine_id '
      'ORDER BY total_qty DESC '
      'LIMIT ?',
      variables: [Variable.withDateTime(since), Variable.withInt(limit)],
      readsFrom: {_db.saleItems, _db.sales, _db.medicines},
    ).get();

    return rows
        .map((row) => TopSellingMedicine(
              medicineId: row.read<int>('medicine_id'),
              medicineName: row.read<String>('name_ar'),
              totalQuantitySold: row.read<int>('total_qty'),
              totalRevenue: row.read<double>('total_revenue'),
            ))
        .toList();
  }

  /// مقارنة مبيعات آخر 7 أيام بالأسبوع الذي قبله
  Future<SalesTrend> getWeeklySalesTrend() async {
    final now = DateTime.now();
    final currentStart = now.subtract(const Duration(days: 7));
    final previousStart = now.subtract(const Duration(days: 14));

    final currentRows = await (_db.select(_db.sales)
          ..where((s) => s.createdAt.isBetweenValues(currentStart, now)))
        .get();
    final previousRows = await (_db.select(_db.sales)
          ..where((s) => s.createdAt.isBetweenValues(previousStart, currentStart)))
        .get();

    return SalesTrend(
      currentPeriodTotal: currentRows.fold<double>(0, (sum, s) => sum + s.totalAmount),
      previousPeriodTotal: previousRows.fold<double>(0, (sum, s) => sum + s.totalAmount),
    );
  }

  /// دفعات ستنتهي صلاحيتها خلال [daysThreshold] يومًا (ولا تزال بها كمية فعلية)
  Future<List<ExpiringBatchInfo>> getExpiringSoonBatches({int daysThreshold = 30}) async {
    final now = DateTime.now();
    final threshold = now.add(Duration(days: daysThreshold));

    final rows = await _db.customSelect(
      'SELECT b.id AS batch_id, b.medicine_id AS medicine_id, m.name_ar AS name_ar, '
      'b.expiry_date AS expiry_date, b.quantity AS quantity '
      'FROM batches b JOIN medicines m ON m.id = b.medicine_id '
      'WHERE b.quantity > 0 AND b.expiry_date IS NOT NULL AND b.expiry_date <= ? '
      'ORDER BY b.expiry_date ASC',
      variables: [Variable.withDateTime(threshold)],
      readsFrom: {_db.batches, _db.medicines},
    ).get();

    return rows
        .map((row) => ExpiringBatchInfo(
              batchId: row.read<int>('batch_id'),
              medicineId: row.read<int>('medicine_id'),
              medicineName: row.read<String>('name_ar'),
              expiryDate: row.read<DateTime>('expiry_date'),
              quantity: row.read<int>('quantity'),
            ))
        .toList();
  }

  /// تقدير عدد الأيام المتبقية لنفاد دواء معيّن، بناءً على متوسط معدل بيعه
  /// اليومي خلال آخر 30 يومًا. يُرجع null إذا لم يُبع الدواء إطلاقًا في هذه الفترة.
  Future<int?> estimateDaysUntilStockout({
    required int medicineId,
    required int currentStock,
    int lookbackDays = 30,
  }) async {
    final since = DateTime.now().subtract(Duration(days: lookbackDays));
    final row = await _db.customSelect(
      'SELECT IFNULL(SUM(si.quantity), 0) AS total_sold '
      'FROM sale_items si JOIN sales s ON s.id = si.sale_id '
      'WHERE si.medicine_id = ? AND s.created_at >= ?',
      variables: [Variable.withInt(medicineId), Variable.withDateTime(since)],
      readsFrom: {_db.saleItems, _db.sales},
    ).getSingle();

    final totalSold = row.read<int>('total_sold');
    if (totalSold <= 0) return null;

    final avgDailySales = totalSold / lookbackDays;
    if (avgDailySales <= 0) return null;

    return (currentStock / avgDailySales).floor();
  }
}
