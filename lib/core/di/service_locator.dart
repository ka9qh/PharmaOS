
// نقطة تسجيل جميع الاعتماديات عبر GetIt - PharmaOS
// يُستدعى مرة واحدة فقط في main.dart قبل تشغيل التطبيق.

import 'package:get_it/get_it.dart';

import '../database/app_database.dart';
import '../security/database_encryption.dart';
import '../security/audit_logger.dart';
import '../security/permissions_service.dart';
import '../services/medicine_units_service.dart';
import '../services/backup_service.dart';
import '../services/report_export_service.dart';
import '../services/stock_alert_service.dart';

import '../../features/doctors/domain/repositories/doctors_repository.dart';
import '../../features/doctors/data/repositories/doctors_repository_impl.dart';
import '../../features/prescriptions/domain/repositories/prescriptions_repository.dart';
import '../../features/prescriptions/data/repositories/prescriptions_repository_impl.dart';
import '../services/day_closing_service.dart';
import '../services/local_analytics_service.dart';
import '../services/pharmacist_chat_service.dart';

import '../../features/settings/data/datasources/settings_datasource.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';

import '../../features/auth/data/datasources/auth_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

import '../../features/categories/data/datasources/categories_datasource.dart';
import '../../features/categories/data/repositories/categories_repository_impl.dart';
import '../../features/categories/domain/repositories/categories_repository.dart';

import '../../features/companies/data/datasources/companies_datasource.dart';
import '../../features/companies/data/repositories/companies_repository_impl.dart';
import '../../features/companies/domain/repositories/companies_repository.dart';

import '../../features/medicines/data/datasources/medicines_datasource.dart';
import '../../features/medicines/data/repositories/medicines_repository_impl.dart';
import '../../features/medicines/domain/repositories/medicines_repository.dart';

import '../../features/inventory/data/datasources/inventory_datasource.dart';
import '../../features/inventory/data/repositories/inventory_repository_impl.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';

import '../../features/sales/data/datasources/sales_datasource.dart';
import '../../features/sales/data/repositories/sales_repository_impl.dart';
import '../../features/sales/domain/repositories/sales_repository.dart';

import '../../features/suppliers/data/datasources/supplier_ledger_datasource.dart';
import '../../features/suppliers/data/datasources/suppliers_datasource.dart';
import '../../features/suppliers/data/repositories/suppliers_repository_impl.dart';
import '../../features/suppliers/domain/repositories/suppliers_repository.dart';

import '../../features/purchases/data/datasources/purchases_datasource.dart';
import '../../features/purchases/data/repositories/purchases_repository_impl.dart';
import '../../features/purchases/domain/repositories/purchases_repository.dart';

import '../../features/accounting/data/datasources/accounting_datasource.dart';
import '../../features/accounting/data/repositories/accounting_repository_impl.dart';
import '../../features/accounting/domain/repositories/accounting_repository.dart';
import '../../core/services/database_seeder_service.dart';
import '../../features/accounting/domain/repositories/general_ledger_repository.dart';
import '../../features/accounting/data/repositories/general_ledger_repository_impl.dart';

import '../../features/wallets/data/datasources/wallets_datasource.dart';
import '../../features/wallets/data/repositories/wallets_repository_impl.dart';
import '../../features/wallets/domain/repositories/wallets_repository.dart';


import '../../features/expenses/data/datasources/expenses_datasource.dart';
import '../../features/expenses/data/repositories/expenses_repository_impl.dart';
import '../../features/expenses/domain/repositories/expenses_repository.dart';

import '../../features/returns/data/datasources/returns_datasource.dart';
import '../../features/returns/data/repositories/returns_repository_impl.dart';
import '../../features/returns/domain/repositories/returns_repository.dart';

import '../../features/reports/data/datasources/reports_datasource.dart';
import '../../features/reports/data/repositories/reports_repository_impl.dart';
import '../../features/reports/domain/repositories/reports_repository.dart';

import '../../features/analytics/data/datasources/analytics_datasource.dart';
import '../../features/analytics/data/repositories/analytics_repository_impl.dart';
import '../../features/analytics/domain/repositories/analytics_repository.dart';

import '../../features/ai/data/datasources/ai_datasource.dart';
import '../../features/ai/data/repositories/ai_repository_impl.dart';
import '../../features/ai/domain/repositories/ai_repository.dart';

import '../../features/stock_alerts/data/datasources/stock_alerts_datasource.dart';
import '../../features/stock_alerts/data/repositories/stock_alerts_repository_impl.dart';
import '../../features/stock_alerts/domain/repositories/stock_alerts_repository.dart';

import '../../features/notifications/data/datasources/notifications_datasource.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';

import '../../features/audit_logs/data/datasources/audit_logs_datasource.dart';
import '../../features/audit_logs/data/repositories/audit_logs_repository_impl.dart';
import '../../features/audit_logs/domain/repositories/audit_logs_repository.dart';

import '../../features/licensing/data/datasources/licensing_datasource.dart';
import '../../features/licensing/data/repositories/licensing_repository_impl.dart';
import '../../features/licensing/domain/repositories/licensing_repository.dart';

import '../../features/users/data/datasources/users_datasource.dart';
import '../../features/users/data/repositories/users_repository_impl.dart';
import '../../features/users/domain/repositories/users_repository.dart';

import '../../features/permissions/data/datasources/permissions_datasource.dart';
import '../../features/permissions/data/repositories/permissions_repository_impl.dart';
import '../../features/permissions/domain/repositories/permissions_repository.dart';

import '../../features/customers/data/datasources/customers_datasource.dart';
import '../../features/customers/data/repositories/customers_repository_impl.dart';
import '../../features/customers/domain/repositories/customers_repository.dart';

import '../../features/workers/data/datasources/workers_datasource.dart';
import '../../features/workers/domain/repositories/workers_repository.dart';
import '../../features/workers/data/repositories/workers_repository_impl.dart';

import '../../features/backup/data/datasources/backup_datasource.dart';
import '../../features/invoices/data/datasources/invoices_datasource.dart';
import '../../features/invoices/data/repositories/invoices_repository_impl.dart';
import '../../features/invoices/domain/repositories/invoices_repository.dart';
import '../../features/cash_register/data/datasources/cash_register_datasource.dart';
import '../../features/cash_register/data/repositories/cash_register_repository_impl.dart';
import '../../features/cash_register/domain/repositories/cash_register_repository.dart';
import '../../features/backup/data/repositories/backup_repository_impl.dart';
import '../../features/backup/domain/repositories/backup_repository.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ---------------- Core ----------------
  final db = AppDatabase(DatabaseEncryption.getEncryptionKey());
  sl.registerSingleton<AppDatabase>(db);
  sl.registerLazySingleton<AuditLogger>(() => AuditLogger(sl<AppDatabase>()));
  // نظام الصلاحيات المتقدم (Users/Roles/Permissions) - يُسجَّل هنا مبكرًا
  // لأن ميزة Auth أدناه تحتاجه فورًا عند تسجيل الدخول لحساب الصلاحيات الفعلية.
  sl.registerLazySingleton<PermissionsService>(
    () => PermissionsService(sl<AppDatabase>(), sl<AuditLogger>()),
  );
  // نظام تعدد وحدات البيع (حبة/شريط/باكت) - راجع medicine_packaging_service.dart
  sl.registerLazySingleton<MedicineUnitsService>(
    () => MedicineUnitsService(sl<AppDatabase>()),
  );

  // ---------------- Feature: Settings ----------------
  // تُسجَّل مبكرًا لأن ReportExportService (أدناه) والعديد من الشاشات تعتمد عليها
  sl.registerLazySingleton<SettingsDataSource>(
    () => SettingsDataSource(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(
      dataSource: sl<SettingsDataSource>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );
  // تحميل الإعدادات فورًا عند الإقلاع لضبط CurrencyFormatter.currentSymbol
  // قبل عرض أي شاشة (وإلا ستظهر القيمة الافتراضية "ريال" للحظة قبل التحميل)
  await sl<SettingsRepository>().load();

  // خدمات التقارير وإغلاق النوبة/اليومية (تُستخدم فقط من ميزة Reports الآن -
  // لا تُستخدم للقفل أو منع أي عملية، راجع التصحيح في day_closing_service.dart)
  sl.registerLazySingleton<BackupService>(() => BackupService());
  sl.registerLazySingleton<ReportExportService>(
    () => ReportExportService(sl<SettingsRepository>()),
  );
  sl.registerLazySingleton<StockAlertService>(
    () => StockAlertService(sl<InventoryRepository>()),
  );
  sl.registerLazySingleton<DayClosingService>(
    () => DayClosingService(
      sl<AppDatabase>(),
      sl<StockAlertService>(),
      sl<ReportExportService>(),
      sl<BackupService>(),
    ),
  );
  sl.registerLazySingleton<LocalAnalyticsService>(
    () => LocalAnalyticsService(sl<AppDatabase>()),
  );

  // ---------------- Feature: Auth ----------------
  sl.registerLazySingleton<AuthDataSource>(
    () => AuthDataSourceImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      dataSource: sl<AuthDataSource>(),
      auditLogger: sl<AuditLogger>(),
      permissionsService: sl<PermissionsService>(),
    ),
  );
  await sl<AuthRepository>().ensureDefaultAdminExists();

  // ---------------- Feature: Categories ----------------
  sl.registerLazySingleton<CategoriesDataSource>(
    () => CategoriesDataSourceImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<CategoriesRepository>(
    () => CategoriesRepositoryImpl(sl<CategoriesDataSource>()),
  );

  // ---------------- Feature: Companies ----------------
  sl.registerLazySingleton<CompaniesDataSource>(
    () => CompaniesDataSourceImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<CompaniesRepository>(
    () => CompaniesRepositoryImpl(sl<CompaniesDataSource>()),
  );

  // ---------------- Feature: Medicines ----------------
  sl.registerLazySingleton<MedicinesDataSource>(
    () => MedicinesDataSourceImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<MedicinesRepository>(
    () => MedicinesRepositoryImpl(
      dataSource: sl<MedicinesDataSource>(),
      categoriesRepository: sl<CategoriesRepository>(),
      companiesRepository: sl<CompaniesRepository>(),
      suppliersRepository: sl<SuppliersRepository>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );

  // ---------------- Feature: Inventory ----------------
  sl.registerLazySingleton<InventoryDataSource>(
    () => InventoryDataSourceImpl(sl<AppDatabase>(), sl<GeneralLedgerRepository>()),
  );
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(sl<InventoryDataSource>(), sl<AuditLogger>()),
  );

  // ---------------- Feature: Sales ----------------
  sl.registerLazySingleton<SalesDataSource>(
    () => SalesDataSourceImpl(sl<AppDatabase>(), sl<GeneralLedgerRepository>()),
  );
  sl.registerLazySingleton<SalesRepository>(
    () => SalesRepositoryImpl(
      dataSource: sl<SalesDataSource>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );

  // ---------------- Feature: Suppliers ----------------
  sl.registerLazySingleton<SupplierLedgerDataSource>(
    () => SupplierLedgerDataSource(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<SuppliersDataSource>(
    () => SuppliersDataSourceImpl(sl<AppDatabase>(), sl<GeneralLedgerRepository>()),
  );
  sl.registerLazySingleton<SuppliersRepository>(
    () => SuppliersRepositoryImpl(sl<SuppliersDataSource>()),
  );

  // ---------------- Feature: Purchases ----------------
  sl.registerLazySingleton<PurchasesDataSource>(
    () => PurchasesDataSourceImpl(sl<AppDatabase>(), sl<GeneralLedgerRepository>()),
  );
  sl.registerLazySingleton<PurchasesRepository>(
    () => PurchasesRepositoryImpl(
      dataSource: sl<PurchasesDataSource>(),
      suppliersRepository: sl<SuppliersRepository>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );

  // ---------------- Feature: Accounting (Vendor Payments) ----------------
  sl.registerLazySingleton<AccountingDataSource>(
    () => AccountingDataSourceImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<AccountingRepository>(
    () => AccountingRepositoryImpl(
      dataSource: sl<AccountingDataSource>(),
      suppliersRepository: sl<SuppliersRepository>(),
    ),
  );

  // ---------------- Feature: Expenses ----------------
  sl.registerLazySingleton<ExpensesDataSource>(
    () => ExpensesDataSourceImpl(sl<AppDatabase>(), sl<GeneralLedgerRepository>()),
  );
  sl.registerLazySingleton<ExpensesRepository>(
    () => ExpensesRepositoryImpl(
      dataSource: sl<ExpensesDataSource>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );

  // ---------------- Feature: Returns ----------------
  sl.registerLazySingleton<ReturnsDataSource>(
    () => ReturnsDataSourceImpl(sl<AppDatabase>(), sl<GeneralLedgerRepository>()),
  );
  sl.registerLazySingleton<ReturnsRepository>(
    () => ReturnsRepositoryImpl(
      dataSource: sl<ReturnsDataSource>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );

  // ---------------- Feature: Reports & Day Closing ----------------
  sl.registerLazySingleton<ReportsDataSource>(
    () => ReportsDataSource(sl<DayClosingService>()),
  );
  sl.registerLazySingleton<ReportsRepository>(
    () => ReportsRepositoryImpl(
      dataSource: sl<ReportsDataSource>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );

  // خدمة الدردشة المحلية الأوفلاين - تُسجَّل هنا لأنها تعتمد على عدة مستودعات
  // مسجَّلة أعلاه (Medicines, Inventory, StockAlert, Analytics, Reports)
  sl.registerLazySingleton<PharmacistChatService>(
    () => PharmacistChatService(
      sl<MedicinesRepository>(),
      sl<InventoryRepository>(),
      sl<StockAlertService>(),
      sl<LocalAnalyticsService>(),
      sl<ReportsRepository>(),
    ),
  );

  // ---------------- Feature: Analytics ----------------
  sl.registerLazySingleton<AnalyticsDataSource>(
    () => AnalyticsDataSource(sl<LocalAnalyticsService>()),
  );
  sl.registerLazySingleton<AnalyticsRepository>(
    () => AnalyticsRepositoryImpl(sl<AnalyticsDataSource>()),
  );

  // ---------------- Feature: AI Insights ----------------
  sl.registerLazySingleton<AiDataSource>(
    () => AiDataSource(sl<LocalAnalyticsService>(), sl<StockAlertService>()),
  );
  sl.registerLazySingleton<AiRepository>(
    () => AiRepositoryImpl(sl<AiDataSource>()),
  );

  // ---------------- Feature: Stock Alerts ----------------
  sl.registerLazySingleton<StockAlertsDataSource>(
    () => StockAlertsDataSource(sl<StockAlertService>()),
  );
  sl.registerLazySingleton<StockAlertsRepository>(
    () => StockAlertsRepositoryImpl(sl<StockAlertsDataSource>()),
  );

  // ---------------- Feature: Notifications ----------------
  sl.registerLazySingleton<NotificationsDataSource>(
    () => NotificationsDataSource(sl<StockAlertService>(), sl<LocalAnalyticsService>()),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(sl<NotificationsDataSource>()),
  );

  // ---------------- Feature: Audit Logs ----------------
  sl.registerLazySingleton<AuditLogsDataSource>(
    () => AuditLogsDataSource(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<AuditLogsRepository>(
    () => AuditLogsRepositoryImpl(sl<AuditLogsDataSource>()),
  );

  // ---------------- Feature: Licensing ----------------
  sl.registerLazySingleton<LicensingDataSource>(
    () => LicensingDataSource(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<LicensingRepository>(
    () => LicensingRepositoryImpl(
      dataSource: sl<LicensingDataSource>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );

  // ---------------- Feature: Users ----------------
  sl.registerLazySingleton<UsersDataSource>(
    () => UsersDataSourceImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<UsersRepository>(
    () => UsersRepositoryImpl(
      dataSource: sl<UsersDataSource>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );

  // ---------------- Feature: Permissions ----------------
  // تعتمد على UsersRepository (أعلاه مباشرة) لعرض قائمة المستخدمين، وعلى
  // PermissionsService (مسجَّلة في قسم Core أعلاه) لكل عمليات القراءة/الكتابة
  // الفعلية على جدول user_permissions.
  sl.registerLazySingleton<PermissionsDataSource>(
    () => PermissionsDataSource(sl<PermissionsService>()),
  );
  sl.registerLazySingleton<PermissionsRepository>(
    () => PermissionsRepositoryImpl(
      dataSource: sl<PermissionsDataSource>(),
      usersRepository: sl<UsersRepository>(),
    ),
  );

  // ---------------- Feature: Customers ----------------
  sl.registerLazySingleton<CustomersDataSource>(
      () => CustomersDataSourceImpl(sl<AppDatabase>(), sl<GeneralLedgerRepository>()));
  sl.registerLazySingleton<CustomersRepository>(
      () => CustomersRepositoryImpl(dataSource: sl(), auditLogger: sl()));
      
  sl.registerLazySingleton<WorkersDataSource>(
      () => WorkersDataSourceImpl(sl()));
  sl.registerLazySingleton<WorkersRepository>(
      () => WorkersRepositoryImpl(sl()));

  // ---------------- Feature: Backup (شاشة عرض - الخدمة الأساسية مسجَّلة أعلاه) ----------------
  sl.registerLazySingleton<BackupDataSource>(
    () => BackupDataSource(sl<BackupService>()),
  );
  
  // Cash Register
  sl.registerLazySingleton<CashRegisterDataSource>(() => CashRegisterDataSourceImpl(sl()));
  sl.registerLazySingleton<CashRegisterRepository>(() => CashRegisterRepositoryImpl(sl()));

  // Invoices
  sl.registerLazySingleton<InvoicesDataSource>(() => InvoicesDataSourceImpl(sl()));
  sl.registerLazySingleton<InvoicesRepository>(() => InvoicesRepositoryImpl(sl()));

  // Wallets
  sl.registerLazySingleton<WalletsDataSource>(() => WalletsDataSource(sl()));
  sl.registerLazySingleton<WalletsRepository>(() => WalletsRepositoryImpl(dataSource: sl()));

  sl.registerLazySingleton<BackupRepository>(
    () => BackupRepositoryImpl(
      dataSource: sl<BackupDataSource>(),
      auditLogger: sl<AuditLogger>(),
    ),
  );

  // ---------------- Feature: Doctors ----------------
  sl.registerLazySingleton<DoctorsRepository>(
    () => DoctorsRepositoryImpl(sl<AppDatabase>()),
  );

  // ---------------- Feature: Prescriptions ----------------
  sl.registerLazySingleton<PrescriptionsRepository>(
    () => PrescriptionsRepositoryImpl(sl<AppDatabase>()),
  );

  // TODO: عند بناء كل ميزة جديدة (Roles كواجهة إدارة أدوار ديناميكية، ...)، سجّل
  // اعتمادياتها هنا بنفس النمط: DataSource -> Repository -> UseCases.
  // (Permissions أصبحت مبنية فعليًا أعلاه - راجع docs/PATCH_NOTES_2026_08_PERMISSIONS.md)

  // ---------------- Feature: General Ledger ----------------
  sl.registerLazySingleton<GeneralLedgerRepository>(
    () => GeneralLedgerRepositoryImpl(sl<AppDatabase>()),
  );

  // ---------------- Core: Seeder ----------------
  sl.registerLazySingleton<DatabaseSeederService>(
    () => DatabaseSeederService(
      sl<AppDatabase>(),
      sl<MedicinesRepository>(),
      sl<CompaniesRepository>(),
      sl<SuppliersRepository>(),
      sl<WalletsRepository>(),
    ),
  );

}
