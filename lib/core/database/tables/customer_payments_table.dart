import 'package:drift/drift.dart';
import 'customers_table.dart';
import 'users_table.dart';

// تسديد يستلمه العميل من الصيدلية لتخفيض دينه (عكس vendor_payments تمامًا،
// لكن هنا العميل هو المدين للصيدلية وليس العكس)
@DataClassName('CustomerPaymentRow')
class CustomerPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  IntColumn get customerId => integer().references(Customers, #id)();
  RealColumn get amount => real()();
  IntColumn get walletId => integer().nullable()();
  TextColumn get paymentMethod => text().withDefault(const Constant('نقدي'))();
  TextColumn get notes => text().nullable()();
  IntColumn get recordedBy => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
