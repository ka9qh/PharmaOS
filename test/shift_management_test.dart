import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:pharmaos/core/database/app_database.dart';
import 'package:pharmaos/core/services/shift_manager_service.dart';
import 'package:pharmaos/core/services/official_date_time_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());

    // Register db with GetIt
    final sl = GetIt.instance;
    await sl.reset();
    sl.registerSingleton<AppDatabase>(db);

    OfficialDateTimeService.initialize();
  });

  tearDown(() async {
    await db.close();
  });

  group('Shift Management & Daily Reconciliation Tests', () {
    test('1. Start new shift with counted opening cash and verify active shift model', () async {
      final shift = await ShiftManagerService.startNewShift(
        cashierName: 'د. أحمد الصيدلاني',
        countedOpeningCash: 15000.0,
        expectedOpeningCash: 15000.0,
        notes: 'بداية يوم عمل جديد',
      );

      expect(shift.id, isNotEmpty);
      expect(shift.cashierName, equals('د. أحمد الصيدلاني'));
      expect(shift.countedOpeningCash, equals(15000.0));
      expect(shift.openingVariance, equals(0.0));
      expect(shift.isClosed, isFalse);

      final active = await ShiftManagerService.getActiveShift();
      expect(active, isNotNull);
      expect(active!.id, equals(shift.id));
    });

    test('2. Start new shift with deficit (عجز في بداية اليوم) and verify negative variance', () async {
      final shift = await ShiftManagerService.startNewShift(
        cashierName: 'محمد الكاشير',
        countedOpeningCash: 12000.0,
        expectedOpeningCash: 15000.0,
        notes: 'عجز في افتتاح الوردية قدره 3000 ريال',
      );

      expect(shift.openingVariance, equals(-3000.0));
      expect(shift.countedOpeningCash, equals(12000.0));
    });

    test('3. Record employee attendance and verify WorkerAttendance table insert', () async {
      final w1 = await db.into(db.workers).insert(
            WorkersCompanion.insert(name: 'صيدلاني 1', jobTitle: const drift.Value('مسؤول وردية')),
          );
      final w2 = await db.into(db.workers).insert(
            WorkersCompanion.insert(name: 'صيدلاني 2', jobTitle: const drift.Value('مساعد صيدلي')),
          );

      await ShiftManagerService.startNewShift(
        cashierName: 'علي الدوام',
        countedOpeningCash: 5000.0,
        expectedOpeningCash: 5000.0,
      );

      final workers = [
        ShiftEmployeeAttendance(workerId: w1, workerName: 'صيدلاني 1', isPresent: true, note: 'حاضر بالموعد'),
        ShiftEmployeeAttendance(workerId: w2, workerName: 'صيدلاني 2', isPresent: false, note: 'إجازة رسمية'),
      ];

      await ShiftManagerService.recordStaffAttendance(workers);

      final attendanceRecords = await db.select(db.workerAttendance).get();
      expect(attendanceRecords.length, equals(2));
      expect(attendanceRecords.first.workerId, equals(w1));
      expect(attendanceRecords.first.isAttended, isTrue);
      expect(attendanceRecords.last.workerId, equals(w2));
      expect(attendanceRecords.last.isAttended, isFalse);
    });

    test('4. Insert sales, expenses, and verify calculateLiveShiftStats & calculateSystemDrawerBalance', () async {
      await ShiftManagerService.startNewShift(
        cashierName: 'فارس المناوبة',
        countedOpeningCash: 10000.0,
        expectedOpeningCash: 10000.0,
      );

      // Insert test category & company
      final catId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(name: 'مسكنات'),
          );
      final compId = await db.into(db.companies).insert(
            CompaniesCompanion.insert(name: 'شركة الدواء'),
          );

      // Insert medicine
      final medId = await db.into(db.medicines).insert(
            MedicinesCompanion.insert(
              nameAr: 'بنادول إكسترا',
              sku: 'PAN-001',
              barcode: '6291100112233',
              categoryId: drift.Value(catId),
              companyId: drift.Value(compId),
              purchasePrice: 500.0,
              sellingPrice: 800.0,
            ),
          );

      // Insert sale (Cash: 800 * 5 = 4000)
      final saleId = await db.into(db.sales).insert(
            SalesCompanion.insert(
              invoiceNumber: 'INV-TEST-001',
              totalAmount: 4000.0,
              discount: const drift.Value(0.0),
              paymentMethod: const drift.Value('نقدي'),
              status: const drift.Value('completed'),
              createdAt: drift.Value(DateTime.now()),
            ),
          );

      // Insert sale item
      await db.into(db.saleItems).insert(
            SaleItemsCompanion.insert(
              saleId: saleId,
              medicineId: medId,
              unitName: const drift.Value('باكت'),
              quantity: 5,
              unitPrice: 800.0,
              subtotal: 4000.0,
              total: const drift.Value(4000.0),
            ),
          );

      // Insert expense (500 YER)
      await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              category: 'مصاريف تشغيلية',
              amount: 500.0,
              notes: const drift.Value('فاتورة ماء'),
              createdAt: drift.Value(DateTime.now()),
            ),
          );

      // Calculate stats
      final stats = await ShiftManagerService.calculateLiveShiftStats();
      expect(stats.totalSalesCount, equals(1));
      expect(stats.totalSalesAmount, equals(4000.0));
      expect(stats.totalCashSales, equals(4000.0));
      expect(stats.totalExpensesAmount, equals(500.0));
      
      // Expected Drawer Cash: 10000 (opening) + 4000 (cash sales) - 500 (expenses) = 13500
      expect(stats.expectedCashInDrawer, equals(13500.0));

      // Top selling items
      expect(stats.topSellingItems.length, equals(1));
      expect(stats.topSellingItems.first.name, equals('بنادول إكسترا'));
      expect(stats.topSellingItems.first.quantity, equals(5));
      expect(stats.topSellingItems.first.totalRevenue, equals(4000.0));
    });

    test('5. Close active shift with cash shortage and auto-expense voucher generation', () async {
      await ShiftManagerService.startNewShift(
        cashierName: 'فارس المناوبة',
        countedOpeningCash: 10000.0,
        expectedOpeningCash: 10000.0,
      );

      // Closing with 9500 (500 deficit) and auto voucher
      final closing = await ShiftManagerService.closeActiveShift(
        countedClosingCash: 9500.0,
        expectedClosingCash: 10000.0,
        varianceReason: 'سحب مالي للمدير نسي تسجيله',
        createExpenseVoucherForDeficit: true,
      );

      expect(closing.shortageAmount, equals(500.0));
      expect(closing.surplusAmount, equals(0.0));
      expect(closing.expenseVoucherCreated, isTrue);

      // Verify active shift is cleared
      final active = await ShiftManagerService.getActiveShift();
      expect(active, isNull);

      // Verify DayClosings record in DB
      final dbClosings = await db.select(db.dayClosings).get();
      expect(dbClosings.length, equals(1));
      expect(dbClosings.first.cashInDrawer, equals(9500.0));

      // Verify Auto Expense Voucher in Expenses table
      final expenses = await db.select(db.expenses).get();
      final autoExpense = expenses.where((e) => e.category == 'تسوية عجز وردية').firstOrNull;
      expect(autoExpense, isNotNull);
      expect(autoExpense!.amount, equals(500.0));
      expect(autoExpense.notes, contains('سحب مالي للمدير نسي تسجيله'));
    });

    test('6. Resume unclosed shift workflow', () async {
      final shift = await ShiftManagerService.startNewShift(
        cashierName: 'كاشير المساء',
        countedOpeningCash: 20000.0,
        expectedOpeningCash: 20000.0,
      );

      final unclosed = await ShiftManagerService.getUnclosedShifts();
      expect(unclosed.length, equals(1));
      expect(unclosed.first.id, equals(shift.id));

      final resumed = await ShiftManagerService.resumeShift(shift.id);
      expect(resumed, isNotNull);
      expect(resumed!.id, equals(shift.id));

      final active = await ShiftManagerService.getActiveShift();
      expect(active!.id, equals(shift.id));
    });
  });
}
