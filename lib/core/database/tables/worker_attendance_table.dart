import 'package:drift/drift.dart';
import 'workers_table.dart';

@DataClassName('WorkerAttendanceRow')
class WorkerAttendance extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workerId => integer().references(Workers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get attendanceDate => dateTime()(); // تاريخ اليوم المسجل فيه الحضور
  BoolColumn get isAttended => boolean().withDefault(const Constant(true))(); // هل حضر أم غاب؟
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  List<Set<Column>> get uniqueKeys => [
        {workerId, attendanceDate}, // الموظف يسجل له حضور مرة واحدة في اليوم
      ];
}
