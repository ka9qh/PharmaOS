// Feature: permissions
// Layer: data/datasources
//
// غلاف رفيع فوق PermissionsService (المسجَّلة كخدمة مشتركة في core/security)
// - نفس نمط StockAlertsDataSource الذي يغلّف StockAlertService، حفاظًا على
// اتساق طبقات Clean Architecture في بقية الميزات.

import '../../../../core/security/permissions_service.dart';
import '../../../../core/security/role_guard.dart';

class PermissionsDataSource {
  final PermissionsService _service;
  PermissionsDataSource(this._service);

  Future<Map<AppPermission, bool>> getOverrides(int userId) => _service.getOverrides(userId);

  Future<void> setOverride({
    required int userId,
    required AppPermission permission,
    required bool granted,
    required int changedByUserId,
  }) {
    return _service.setOverride(
      userId: userId,
      permission: permission,
      granted: granted,
      changedByUserId: changedByUserId,
    );
  }

  Future<void> clearOverride({
    required int userId,
    required AppPermission permission,
    required int changedByUserId,
  }) {
    return _service.clearOverride(
      userId: userId,
      permission: permission,
      changedByUserId: changedByUserId,
    );
  }
}
