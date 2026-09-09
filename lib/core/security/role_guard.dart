// التحقق من صلاحيات المستخدم قبل تنفيذ أي عملية حساسة
// المصفوفة الكاملة موثقة في docs/SECURITY_GUIDELINES.md
//
// تحديث: نظام الصلاحيات الكامل (Users/Roles/Permissions)
// ============================================================================
// هذا الملف يبقى "الأساس الافتراضي" (Role Defaults) - سريع، متزامن (Sync)،
// مُترجم مع الكود مباشرة، بدون أي استعلام قاعدة بيانات. فوقه طبقة جديدة في
// core/security/permissions_service.dart تسمح لصاحب الصيدلية بتخصيص كل
// صلاحية لكل مستخدم على حدة (تفعيل/تعطيل مستقل عن الدور الافتراضي)، عبر جدول
// user_permissions - تحقيقًا لمتطلب "كل صلاحية مستقلة ويمكن تفعيلها أو
// تعطيلها" المذكور صراحة في مواصفات المشروع.
//
// أضفنا دورين لم يكونا موجودين (pharmacist, employee) و8 صلاحيات جديدة
// مطابقة لما ورد صراحة في قسم "صلاحيات أكثر احترافية" بمواصفات المشروع.
// القيم الافتراضية أدناه معقولة ومبنية على طبيعة كل دور، لكنها جميعًا قابلة
// للتخصيص لاحقًا من شاشة "الصلاحيات" لكل مستخدم دون تعديل أي كود.

import 'package:flutter/material.dart' as import_material;
import '../../features/auth/presentation/providers/auth_provider.dart';

enum AppRole { owner, manager, accountant, pharmacist, cashier, inventoryClerk, employee }

enum AppPermission {
  viewProfits, // مشاهدة الأرباح
  editPrices, // تعديل الأسعار
  voidInvoice, // إلغاء فاتورة
  deleteInvoice, // حذف فاتورة (أشد من الإلغاء - حذف نهائي من السجل)
  manageUsers, // إدارة المستخدمين (إضافة/تعطيل/تغيير كلمات مرور)
  usePos, // استخدام شاشة نقطة البيع
  deleteClosingRecord, // حذف تقرير إغلاق خاطئ
  printReports, // طباعة/تصدير التقارير
  openDay, // فتح اليومية
  closeDay, // إغلاق اليومية
  editInventory, // تعديل كميات المخزون يدويًا (خارج البيع/الشراء الطبيعي)
  editMedicineData, // تعديل بيانات صنف دواء (الاسم، السعر الأساسي، إلخ)
  backup, // إنشاء نسخة احتياطية
  restoreBackup, // استعادة نسخة احتياطية (عملية حساسة - تستبدل البيانات الحالية)
}

class RoleGuard {
  RoleGuard._();

  static const Map<AppRole, Set<AppPermission>> _matrix = {
    AppRole.owner: {
      AppPermission.viewProfits,
      AppPermission.editPrices,
      AppPermission.voidInvoice,
      AppPermission.deleteInvoice,
      AppPermission.manageUsers,
      AppPermission.usePos,
      AppPermission.deleteClosingRecord,
      AppPermission.printReports,
      AppPermission.openDay,
      AppPermission.closeDay,
      AppPermission.editInventory,
      AppPermission.editMedicineData,
      AppPermission.backup,
      AppPermission.restoreBackup,
    },
    AppRole.manager: {
      AppPermission.viewProfits,
      AppPermission.editPrices,
      AppPermission.voidInvoice,
      AppPermission.deleteInvoice,
      AppPermission.usePos,
      AppPermission.deleteClosingRecord,
      AppPermission.printReports,
      AppPermission.openDay,
      AppPermission.closeDay,
      AppPermission.editInventory,
      AppPermission.editMedicineData,
      AppPermission.backup,
      // لا manageUsers ولا restoreBackup افتراضيًا - عمليات حساسة جدًا،
      // متروكة لصاحب الصيدلية ليمنحها يدويًا إن أراد.
    },
    AppRole.accountant: {
      AppPermission.viewProfits,
      AppPermission.printReports,
      AppPermission.backup,
      AppPermission.openDay,
      AppPermission.closeDay,
    },
    AppRole.pharmacist: {
      AppPermission.usePos,
      AppPermission.editMedicineData,
      AppPermission.printReports,
    },
    AppRole.cashier: {
      AppPermission.usePos,
    },
    AppRole.inventoryClerk: {
      AppPermission.editInventory,
      AppPermission.editMedicineData,
    },
    AppRole.employee: {
      AppPermission.usePos,
    },
  };

  static bool can(AppRole role, AppPermission permission) {
    return _matrix[role]?.contains(permission) ?? false;
  }

  /// يتحقق من الصلاحية ويعرض حوار تحذير إذا لم يكن مسموحاً
  static void checkPermission({
    required dynamic context, // BuildContext
    required dynamic ref, // WidgetRef
    required AppPermission permission,
    required Function() onGranted,
  }) {
    final user = ref.read(authNotifierProvider).user;
    if (user != null && user.can(permission)) {
      onGranted();
    } else {
      if (context != null) {
        import_material.ScaffoldMessenger.of(context).showSnackBar(
          import_material.SnackBar(
            content: import_material.Text('عفواً، ليس لديك الصلاحية (${labelFor(permission)}) للقيام بهذا الإجراء.'),
            backgroundColor: import_material.Colors.red.shade800,
          ),
        );
      }
    }
  }

  /// الصلاحيات الافتراضية لدور معيّن - نقطة البداية قبل تطبيق أي تخصيص فردي
  /// (راجع PermissionsService.effectivePermissionsFor).
  static Set<AppPermission> defaultsFor(AppRole role) {
    return Set.unmodifiable(_matrix[role] ?? const <AppPermission>{});
  }

  static AppRole roleFromString(String value) {
    return AppRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => AppRole.cashier, // الأكثر أمانًا كافتراضي عند القيمة غير المعروفة
    );
  }

  /// اسم الصلاحية بالعربية - تُستخدم في شاشة الصلاحيات وأي مكان يعرضها للمستخدم.
  static String labelFor(AppPermission permission) {
    switch (permission) {
      case AppPermission.viewProfits:
        return 'مشاهدة الأرباح';
      case AppPermission.editPrices:
        return 'تعديل الأسعار';
      case AppPermission.voidInvoice:
        return 'إلغاء فاتورة';
      case AppPermission.deleteInvoice:
        return 'حذف فاتورة';
      case AppPermission.manageUsers:
        return 'إدارة المستخدمين';
      case AppPermission.usePos:
        return 'استخدام نقطة البيع';
      case AppPermission.deleteClosingRecord:
        return 'حذف تقرير إغلاق';
      case AppPermission.printReports:
        return 'طباعة/تصدير التقارير';
      case AppPermission.openDay:
        return 'فتح اليومية';
      case AppPermission.closeDay:
        return 'إغلاق اليومية';
      case AppPermission.editInventory:
        return 'تعديل المخزون يدويًا';
      case AppPermission.editMedicineData:
        return 'تعديل بيانات الأدوية';
      case AppPermission.backup:
        return 'إنشاء نسخة احتياطية';
      case AppPermission.restoreBackup:
        return 'استعادة نسخة احتياطية';
    }
  }
}
