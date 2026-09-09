import 'package:flutter/material.dart';

class UnitConverter {
  /// تحويل إجمالي الحبات إلى نص منسق بحسب نوع الدواء
  static String formatQuantity({
    required int totalPills,
    int? qtyPerCarton,
    int? qtyPerPack,
    int? qtyPerStrip,
    int medicineType = 1,
  }) {
    if (totalPills <= 0) {
      if (medicineType == 3) return '0 علبة';
      if (medicineType == 2) return '0 إبرة';
      return '0 حبة';
    }

    int remaining = totalPills;
    List<String> parts = [];

    final qCarton = (qtyPerCarton != null && qtyPerCarton > 0) ? qtyPerCarton : 1;
    final qPack = (qtyPerPack != null && qtyPerPack > 0) ? qtyPerPack : 1;
    final qStrip = (qtyPerStrip != null && qtyPerStrip > 0) ? qtyPerStrip : 1;

    if (medicineType == 2) {
      // إبر وحقن: كرتون + باكت + حبة (إبرة)
      final cartonBase = qCarton * qPack;
      if (qtyPerCarton != null && qtyPerCarton > 0 && cartonBase > 0) {
        int cartons = remaining ~/ cartonBase;
        if (cartons > 0) {
          parts.add('$cartons كرتون');
          remaining %= cartonBase;
        }
      }
      if (qtyPerPack != null && qtyPerPack > 0) {
        int packs = remaining ~/ qPack;
        if (packs > 0) {
          parts.add('$packs باكت');
          remaining %= qPack;
        }
      }
      if (remaining > 0 || parts.isEmpty) {
        parts.add('$remaining حبة (إبرة)');
      }

    } else if (medicineType == 3) {
      // علب ومعلبات وزجاج ومغذيات: كرتون + علبة
      if (qtyPerCarton != null && qtyPerCarton > 0) {
        int cartons = remaining ~/ qCarton;
        if (cartons > 0) {
          parts.add('$cartons كرتون');
          remaining %= qCarton;
        }
      }
      if (remaining > 0 || parts.isEmpty) {
        parts.add('$remaining علبة');
      }

    } else if (medicineType == 4) {
      // فراشات وشرنجات: كرتون + حبة
      if (qtyPerCarton != null && qtyPerCarton > 0) {
        int cartons = remaining ~/ qCarton;
        if (cartons > 0) {
          parts.add('$cartons كرتون');
          remaining %= qCarton;
        }
      }
      if (remaining > 0 || parts.isEmpty) {
        parts.add('$remaining حبة');
      }

    } else {
      // حبوب وأقراص (1): كرتون + باكت + شريط + حبة
      final packBase = qPack * qStrip;
      final cartonBase = qCarton * packBase;

      if (qtyPerCarton != null && qtyPerCarton > 0 && cartonBase > 0) {
        int cartons = remaining ~/ cartonBase;
        if (cartons > 0) {
          parts.add('$cartons كرتون');
          remaining %= cartonBase;
        }
      }
      if (qtyPerPack != null && qtyPerPack > 0 && packBase > 0) {
        int packs = remaining ~/ packBase;
        if (packs > 0) {
          parts.add('$packs باكت');
          remaining %= packBase;
        }
      }
      if (qtyPerStrip != null && qtyPerStrip > 0) {
        int strips = remaining ~/ qStrip;
        if (strips > 0) {
          parts.add('$strips شريط');
          remaining %= qStrip;
        }
      }
      if (remaining > 0 || parts.isEmpty) {
        parts.add('$remaining حبة');
      }
    }

    return parts.join(' و ');
  }

  /// تحويل الكميات المدخلة إلى إجمالي الحبات (الوحدات الصغرى) بدقة بحسب نوع الدواء
  static int toTotalPills({
    int cartons = 0,
    int packs = 0,
    int strips = 0,
    int pills = 0,
    int? qtyPerCarton,
    int? qtyPerPack,
    int? qtyPerStrip,
    int medicineType = 1,
  }) {
    int total = pills;
    final qCarton = (qtyPerCarton != null && qtyPerCarton > 0) ? qtyPerCarton : 1;
    final qPack = (qtyPerPack != null && qtyPerPack > 0) ? qtyPerPack : 1;
    final qStrip = (qtyPerStrip != null && qtyPerStrip > 0) ? qtyPerStrip : 1;

    if (medicineType == 2) {
      // إبر وحقن: كرتون (يحوي بواكت) + باكت (يحوي إبر) + إبر
      if (qtyPerPack != null && qtyPerPack > 0) {
        total += packs * qPack;
      } else {
        total += packs;
      }
      if (qtyPerCarton != null && qtyPerCarton > 0) {
        total += cartons * qCarton * (qtyPerPack != null && qtyPerPack > 0 ? qPack : 1);
      } else {
        total += cartons;
      }

    } else if (medicineType == 3 || medicineType == 4) {
      // علب/شرنجات: كرتون (يحوي علب/حبات) + علبة أو حبة
      // في حال كتب في الباكت أو الحبة
      total += packs;
      if (qtyPerCarton != null && qtyPerCarton > 0) {
        total += cartons * qCarton;
      } else {
        total += cartons;
      }

    } else {
      // حبوب وأقراص (1)
      final packBase = (qtyPerStrip != null && qtyPerStrip > 0) ? (qPack * qStrip) : qPack;
      final cartonBase = (qtyPerCarton != null && qtyPerCarton > 0) ? (qCarton * packBase) : packBase;

      if (qtyPerStrip != null && qtyPerStrip > 0) total += strips * qStrip;
      if (qtyPerPack != null && qtyPerPack > 0) total += packs * packBase;
      if (qtyPerCarton != null && qtyPerCarton > 0) total += cartons * cartonBase;
    }

    return total;
  }
}
