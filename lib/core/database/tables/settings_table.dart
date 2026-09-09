import 'package:drift/drift.dart';

// جدول إعدادات مرن بصيغة (مفتاح/قيمة) بدل أعمدة ثابتة - يسمح بإضافة إعدادات
// جديدة مستقبلاً دون الحاجة لـ Migration في قاعدة البيانات.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
