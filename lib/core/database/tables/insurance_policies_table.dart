import 'package:drift/drift.dart';
import 'customers_table.dart';
import 'insurance_companies_table.dart';

/// بوالص التأمين الطبي - تربط العميل بشركة التأمين
/// كل عميل يمكن أن يكون لديه بوليصة واحدة أو أكثر
@DataClassName('InsurancePolicyRow')
class InsurancePolicies extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get insuranceCompanyId => integer().references(InsuranceCompanies, #id)();
  
  TextColumn get policyNumber => text()(); // رقم البوليصة / بطاقة التأمين
  
  /// نسبة تغطية هذه البوليصة (تتجاوز النسبة الافتراضية للشركة)
  RealColumn get coveragePercent => real().withDefault(const Constant(0))();
  
  /// الحد الأقصى للتغطية الشهرية (0 = بلا حد)
  RealColumn get monthlyLimit => real().withDefault(const Constant(0))();
  
  /// المبلغ المستهلك من الحد الشهري (يُصفَّر كل شهر)
  RealColumn get monthlyUsed => real().withDefault(const Constant(0))();
  
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()(); // null = سارية لأجل غير مسمى
  
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
