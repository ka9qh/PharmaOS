import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaos/core/utils/unit_converter.dart';
import 'package:pharmaos/core/services/windows_biometric_service.dart';

void main() {
  group('اختبارات الوحدات الذكية والمحاسبة لمختلف أنواع الأدوية', () {
    test('نوع 2: إبر وحقن - كرتون وباكت وحبة (إبرة)', () {
      // كرتون يحوي 10 بواكت، والباكت يحوي 5 إبر
      const qtyPerCarton = 10;
      const qtyPerPack = 5;
      const medicineType = 2;

      // 1 كرتون + 2 باكت + 3 إبر
      // 1 كرتون = 10 * 5 = 50 إبرة
      // 2 باكت = 2 * 5 = 10 إبر
      // 3 إبر = 3
      // الإجمالي = 63 إبرة
      final totalPills = UnitConverter.toTotalPills(
        cartons: 1,
        packs: 2,
        strips: 0,
        pills: 3,
        qtyPerCarton: qtyPerCarton,
        qtyPerPack: qtyPerPack,
        medicineType: medicineType,
      );

      expect(totalPills, equals(63));

      // التنسيق النصي العكسي
      final formatted = UnitConverter.formatQuantity(
        totalPills: 63,
        qtyPerCarton: qtyPerCarton,
        qtyPerPack: qtyPerPack,
        medicineType: medicineType,
      );

      expect(formatted, contains('1 كرتون'));
      expect(formatted, contains('2 باكت'));
      expect(formatted, contains('3 حبة (إبرة)'));
    });

    test('نوع 3: أدوية معلبة وزجاج ومغذيات - كرتون وعلبة', () {
      // كرتون يحوي 12 علبة
      const qtyPerCarton = 12;
      const medicineType = 3;

      // 2 كرتون + 5 علب
      // 2 * 12 + 5 = 29 علبة
      final totalPills = UnitConverter.toTotalPills(
        cartons: 2,
        packs: 0,
        strips: 0,
        pills: 5,
        qtyPerCarton: qtyPerCarton,
        medicineType: medicineType,
      );

      expect(totalPills, equals(29));

      final formatted = UnitConverter.formatQuantity(
        totalPills: 29,
        qtyPerCarton: qtyPerCarton,
        medicineType: medicineType,
      );

      expect(formatted, contains('2 كرتون'));
      expect(formatted, contains('5 علبة'));
    });

    test('نوع 4: فراشات وشرنجات - كرتون وحبة', () {
      // كرتون يحوي 100 حبة
      const qtyPerCarton = 100;
      const medicineType = 4;

      // 3 كرتون + 15 حبة = 315 حبة
      final totalPills = UnitConverter.toTotalPills(
        cartons: 3,
        packs: 0,
        strips: 0,
        pills: 15,
        qtyPerCarton: qtyPerCarton,
        medicineType: medicineType,
      );

      expect(totalPills, equals(315));

      final formatted = UnitConverter.formatQuantity(
        totalPills: 315,
        qtyPerCarton: qtyPerCarton,
        medicineType: medicineType,
      );

      expect(formatted, contains('3 كرتون'));
      expect(formatted, contains('15 حبة'));
    });

    test('نوع 1: حبوب وأقراص - كرتون وباكت وشريط وحبة', () {
      // كرتون يحوي 20 باكت، باكت يحوي 3 أشرطة، شريط يحوي 10 حبات
      const qtyPerCarton = 20;
      const qtyPerPack = 3;
      const qtyPerStrip = 10;
      const medicineType = 1;

      // 1 كرتون + 1 باكت + 1 شريط + 4 حبات
      // 1 كرتون = 20 * 3 * 10 = 600
      // 1 باكت = 3 * 10 = 30
      // 1 شريط = 10
      // 4 حبات = 4
      // الإجمالي = 644
      final totalPills = UnitConverter.toTotalPills(
        cartons: 1,
        packs: 1,
        strips: 1,
        pills: 4,
        qtyPerCarton: qtyPerCarton,
        qtyPerPack: qtyPerPack,
        qtyPerStrip: qtyPerStrip,
        medicineType: medicineType,
      );

      expect(totalPills, equals(644));

      final formatted = UnitConverter.formatQuantity(
        totalPills: 644,
        qtyPerCarton: qtyPerCarton,
        qtyPerPack: qtyPerPack,
        qtyPerStrip: qtyPerStrip,
        medicineType: medicineType,
      );

      expect(formatted, contains('1 كرتون'));
      expect(formatted, contains('1 باكت'));
      expect(formatted, contains('1 شريط'));
      expect(formatted, contains('4 حبة'));
    });
  });

  group('فحص البصمة الحيوية لنظام Windows Hello', () {
    test('التحقق من توفر Windows Hello على جهاز اللابتوب', () async {
      final available = await WindowsBiometricService.isBiometricAvailable();
      print('Windows Hello biometric available: $available');
      expect(available, isA<bool>());
    });
  });
}
