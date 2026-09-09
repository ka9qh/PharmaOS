import 'package:drift/drift.dart';

@DataClassName('WorkerRow')
class Workers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get phone => text().nullable()();
  TextColumn get jobTitle => text().nullable()();
  RealColumn get salary => real().withDefault(const Constant(0))();
  RealColumn get dailyAllowance => real().withDefault(const Constant(0))();
  RealColumn get dailyWithdrawalLimit => real().nullable()();
  // إذا كان true، فالمصروف اليومي يُخصم من الراتب (راتب بس). 
  // إذا كان false، فالمصروف يُضاف كبدل منفصل ولا يُخصم من الراتب الأساسي (راتب مع مصروف).
  BoolColumn get allowanceIsDeducted => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name},
      ];
}
