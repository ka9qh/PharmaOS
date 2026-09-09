// خدمة تعدد وحدات البيع (حبة/شريط/باكت) لكل دواء
// ============================================================================
// الوحدة الأساسية دائمًا هي medicines.unit الموجودة أصلاً (مثلاً "حبة" أو
// "إبرة") - وهي وحدة التخزين الفعلية في batches.quantity وsale_items.quantity
// (لم تتغيّر، ولا داعي لتغييرها: كل الكميات بالنظام مخزَّنة بالوحدة الأساسية
// دائمًا). هذه الخدمة تضيف طبقة تحويل فوقها فقط للعرض والإدخال:
// - شريط = عدد N من الوحدة الأساسية (مثلاً 10 حبات)
// - باكت = عدد M من الشريط (مثلاً 10 شرائط = 100 حبة)
// إبرة تُباع مفردة تلقائيًا إن لم يُعرَّف لها شريط/باكت - لا حاجة لأي إعداد
// خاص، هي أصلاً الوحدة الأساسية.

import 'package:drift/drift.dart';
import '../database/app_database.dart';

enum PackagingLevel { base, middle, large }

class MedicinePackagingConfig {
  final int medicineId;
  final String? middleUnitName; // مثال: "شريط"
  final int? unitsPerMiddle; // مثال: 10 (حبة لكل شريط)
  final String? largeUnitName; // مثال: "باكت"
  final int? middlesPerLarge; // مثال: 10 (شريط لكل باكت)

  const MedicinePackagingConfig({
    required this.medicineId,
    this.middleUnitName,
    this.unitsPerMiddle,
    this.largeUnitName,
    this.middlesPerLarge,
  });

  bool get hasMiddleLevel => middleUnitName != null && (unitsPerMiddle ?? 0) > 0;
  bool get hasLargeLevel => hasMiddleLevel && largeUnitName != null && (middlesPerLarge ?? 0) > 0;

  /// عدد الوحدات الأساسية لكل مستوى - يُستخدم لتحويل أي إدخال لوحدة أساسية.
  int factorFor(PackagingLevel level) {
    switch (level) {
      case PackagingLevel.base:
        return 1;
      case PackagingLevel.middle:
        return unitsPerMiddle ?? 1;
      case PackagingLevel.large:
        return (unitsPerMiddle ?? 1) * (middlesPerLarge ?? 1);
    }
  }
}

class MedicinePackagingService {
  final AppDatabase _db;
  MedicinePackagingService(this._db);

  Future<MedicinePackagingConfig?> getConfig(int medicineId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM medicine_packaging WHERE medicine_id = ?;',
      variables: [Variable.withInt(medicineId)],
    ).get();
    if (rows.isEmpty) return null;

    final row = rows.first;
    final middleUnitName = row.read<String>('middle_unit_name');
    final unitsPerMiddle = row.read<int>('units_per_middle');
    final largeUnitName = row.read<String>('large_unit_name');
    final middlesPerLarge = row.read<int>('middles_per_large');

    return MedicinePackagingConfig(
      medicineId: medicineId,
      middleUnitName: middleUnitName.isEmpty ? null : middleUnitName,
      unitsPerMiddle: unitsPerMiddle == 0 ? null : unitsPerMiddle,
      largeUnitName: largeUnitName.isEmpty ? null : largeUnitName,
      middlesPerLarge: middlesPerLarge == 0 ? null : middlesPerLarge,
    );
  }

  Future<void> setConfig(MedicinePackagingConfig config) async {
    // نستخدم قيمًا محايدة (0 / نص فارغ) بدل NULL في الربط الفعلي للاستعلام
    // لتفادي أي غموض حول تمثيل NULL في customStatement - وليس لأن القيمة
    // الحقيقية صفر؛ getConfig يعيد تحويلها لـ null عند القراءة (أدناه).
    await _db.customStatement(
      'INSERT INTO medicine_packaging '
      '(medicine_id, middle_unit_name, units_per_middle, large_unit_name, middles_per_large) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(medicine_id) DO UPDATE SET '
      'middle_unit_name = excluded.middle_unit_name, '
      'units_per_middle = excluded.units_per_middle, '
      'large_unit_name = excluded.large_unit_name, '
      'middles_per_large = excluded.middles_per_large;',
      [
        Variable.withInt(config.medicineId),
        Variable.withString(config.middleUnitName ?? ''),
        Variable.withInt(config.unitsPerMiddle ?? 0),
        Variable.withString(config.largeUnitName ?? ''),
        Variable.withInt(config.middlesPerLarge ?? 0),
      ],
    );
  }

  Future<void> clearConfig(int medicineId) async {
    await _db.customStatement(
      'DELETE FROM medicine_packaging WHERE medicine_id = ?;',
      [Variable.withInt(medicineId)],
    );
  }
}
