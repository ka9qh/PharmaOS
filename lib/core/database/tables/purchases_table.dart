import 'package:drift/drift.dart';
import 'suppliers_table.dart';
import 'wallets_table.dart';

@DataClassName('PurchaseRow')
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  TextColumn get purchaseNumber => text()(); // مرجعنا الداخلي: PUR-yyyyMMdd-NNNN
  TextColumn get supplierInvoiceRef => text().nullable()(); // رقم فاتورة المورد الورقية (اختياري)
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  RealColumn get totalAmount => real()();
  
  // الضرائب
  RealColumn get subTotal => real().withDefault(const Constant(0.0))(); // المبلغ قبل الضريبة
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))(); // قيمة الضريبة الإجمالية

  // المبلغ المدفوع فورًا عند استلام البضاعة. المتبقي يُحسب دائمًا من الفرق
  // (totalAmount - paidAmount) ولا يُخزَّن كعمود منفصل تجنبًا لتضارب البيانات
  // (راجع docs/DATABASE_DESIGN.md - قرار Phase 4).
  RealColumn get paidAmount => real().withDefault(const Constant(0))();

  TextColumn get paymentMethod =>
      text().withDefault(const Constant('نقدي'))(); // 'نقدي', 'محفظة'
      
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();

  TextColumn get invoiceImagePath => text().nullable()(); // مسار صورة الفاتورة بعد مسحها بالذكاء الاصطناعي

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {purchaseNumber},
      ];
}
