import '../../../auth/domain/entities/auth_entity.dart';
import '../../../../core/security/role_guard.dart';

class ReportsController {
  ReportsController._();

  static bool canDeleteClosingRecord(AuthUser user) {
    return user.can(AppPermission.deleteClosingRecord);
  }
}
