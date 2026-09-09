import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaos/features/invoices/domain/entities/invoice_entity.dart';

void main() {
  group('InvoiceItemEntity Unit Pricing Calculations', () {
    test('Calculates pill and strip prices correctly for Panadol Extra', () {
      // Panadol Extra:
      // Pack purchase price: 150 YER, Pack sell price: 200 YER
      // 2 strips per pack, 10 pills per strip -> 20 pills per pack
      const item = InvoiceItemEntity(
        id: 1,
        medicineId: 10,
        medicineName: 'بانادول اكسترا',
        quantity: 240, // 12 packs * 20 pills = 240 pills
        unitPrice: 150, // pack purchase price
        subtotal: 1800, // 12 packs * 150 = 1800
        conversionFactor: 20,
        medicineType: 1, // strip type
        qtyPerPack: 2, // 2 strips per pack
        qtyPerStrip: 10, // 10 pills per strip
        qtyPerCarton: 1,
        purchasePrice: 150.0,
        sellingPrice: 200.0,
        selectedQuantity: 12,
        unitName: 'باكت',
      );

      // Verify pills calculation:
      expect(item.calculatedPillsPerStrip, equals(10));
      expect(item.calculatedPillsPerPack, equals(20));

      // Pack purchase cost: 150
      expect(item.packPurchaseCost, equals(150.0));
      // Strip purchase cost: 150 / 2 = 75.0
      expect(item.stripPurchaseCost, equals(75.0));
      // Pill purchase cost: 150 / 20 = 7.5 (NOT 150!)
      expect(item.pillPurchaseCost, equals(7.5));

      // Pack selling price: 200
      expect(item.packSellingPrice, equals(200.0));
      // Strip selling price: 200 / 2 = 100.0
      expect(item.stripSellingPrice, equals(100.0));
      // Pill selling price: 200 / 20 = 10.0 (NOT 200!)
      expect(item.pillSellingPrice, equals(10.0));

      // Unit display with unit:
      expect(item.displayUnitPriceWithUnit, contains('باكت'));
      expect(item.displayUnitPriceWithUnit, isNot(contains('حبة')));
    });

    test('Handles item with 10 strips of 10 pills per pack', () {
      const item = InvoiceItemEntity(
        id: 2,
        medicineId: 11,
        medicineName: 'أموكسيسيلين',
        quantity: 100, // 1 pack = 100 pills
        unitPrice: 500,
        subtotal: 500,
        conversionFactor: 100,
        medicineType: 1,
        qtyPerPack: 10,
        qtyPerStrip: 10,
        purchasePrice: 500.0,
        sellingPrice: 700.0,
        selectedQuantity: 1,
        unitName: 'باكت',
      );

      expect(item.calculatedPillsPerStrip, equals(10));
      expect(item.calculatedPillsPerPack, equals(100));

      expect(item.packPurchaseCost, equals(500.0));
      expect(item.stripPurchaseCost, equals(50.0));
      expect(item.pillPurchaseCost, equals(5.0));

      expect(item.packSellingPrice, equals(700.0));
      expect(item.stripSellingPrice, equals(70.0));
      expect(item.pillSellingPrice, equals(7.0));
    });

    test('Linked returns model retains all fields properly', () {
      const retItem = InvoiceItemEntity(
        id: 101,
        medicineId: 10,
        medicineName: 'بانادول اكسترا',
        quantity: 10,
        unitPrice: 7.5,
        subtotal: 75.0,
        conversionFactor: 1,
        selectedQuantity: 1,
        unitName: 'شريط',
        formattedQuantity: '1 شريط',
      );

      final ret = InvoiceReturnRefEntity(
        returnId: 5,
        returnNumber: 'RET-C-0005',
        returnDate: DateTime(2026, 9, 6),
        totalAmount: 75.0,
        settlementMethod: 'refund',
        reason: 'تالف من العميل',
        returnType: 'CUSTOMER_RETURN',
        items: const [retItem],
      );

      final inv = InvoiceEntity(
        id: 1,
        invoiceNumber: 'INV-0001',
        date: DateTime(2026, 9, 5),
        totalAmount: 1800,
        discount: 0,
        paymentMethod: 'نقداً',
        type: 'SALE',
        partyName: 'عميل نقدي',
        items: const [],
        linkedReturns: [ret],
        status: 'partially_returned',
      );

      expect(inv.linkedReturns.length, equals(1));
      expect(inv.linkedReturns.first.returnNumber, equals('RET-C-0005'));
      expect(inv.linkedReturns.first.items.first.formattedQuantity, equals('1 شريط'));
      expect(inv.status, equals('partially_returned'));
    });
  });
}
