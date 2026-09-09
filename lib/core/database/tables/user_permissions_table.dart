import 'package:drift/drift.dart';
import 'users_table.dart';

@DataClassName('UserPermissionRow')
class UserPermissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // المستخدم
  IntColumn get userId => integer().references(Users, #id)();
  
  // اسم الصلاحية (مثلاً viewProfits, editPrices)
  TextColumn get permission => text()();
  
  // هل هي مفعلة أم معطلة؟
  // (مفعلة تعني منحه الصلاحية حتى لو دوره لا يملكها، معطلة تعني سحبها منه حتى لو دوره يملكها)
  BoolColumn get isGranted => boolean().withDefault(const Constant(true))();
  
  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, permission}, // لا يمكن تكرار نفس الصلاحية لنفس المستخدم مرتين
      ];
}
