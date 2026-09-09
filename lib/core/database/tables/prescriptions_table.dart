import 'package:drift/drift.dart';
import 'customers_table.dart';
import 'doctors_table.dart';

@DataClassName('PrescriptionRow')
class Prescriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // A prescription can belong to a customer
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  
  // A prescription is written by a doctor
  IntColumn get doctorId => integer().nullable().references(Doctors, #id)();
  
  // Basic info
  TextColumn get prescriptionNumber => text().nullable()();
  DateTimeColumn get issueDate => dateTime().nullable()();
  TextColumn get diagnosis => text().nullable()();
  TextColumn get notes => text().nullable()();
  
  // Image path of the prescription if scanned
  TextColumn get imagePath => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
