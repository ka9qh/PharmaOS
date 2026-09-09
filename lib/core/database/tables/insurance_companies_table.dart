import 'package:drift/drift.dart';

/// شركات التأمين الطبي (مثلاً: يمن سوفت للتأمين، الأهلية، إلخ)
@DataClassName('InsuranceCompanyRow')
class InsuranceCompanies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get contactPerson => text().nullable()(); // شخص التواصل
  
  /// نسبة التغطية الافتراضية لهذه الشركة (0-100)
  /// يمكن تجاوزها في كل بوليصة على حدة
  RealColumn get defaultCoveragePercent => real().withDefault(const Constant(0))();
  
  /// الحد الأقصى للتغطية لكل فاتورة (0 = بلا حد)
  RealColumn get maxCoveragePerInvoice => real().withDefault(const Constant(0))();
  
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {name},
  ];
}
