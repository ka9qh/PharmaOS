// جدول المستخدمين - PharmaOS
// ملاحظة: pharmacyId موجود من الآن تحضيرًا لدعم تعدد الصيدليات مستقبلاً
// كمنتج يُباع (راجع docs/LICENSING_STRATEGY.md)، رغم أن النظام أحادي الصيدلية حاليًا.

import 'package:drift/drift.dart';

@DataClassName('UserRow')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  TextColumn get fullName => text().withLength(min: 1, max: 100)();
  TextColumn get username => text().withLength(min: 3, max: 50)();
  TextColumn get passwordHash => text()();

  // الأدوار: owner | manager | accountant | cashier | inventory_clerk
  // TODO: عند بناء ميزة Roles/Permissions الكاملة (المرحلة اللاحقة)، يُستبدل هذا
  // الحقل النصي بعلاقة حقيقية مع جدول roles منفصل يحمل صلاحيات مرنة.
  TextColumn get role => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get mustChangePassword =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {username},
      ];
}
