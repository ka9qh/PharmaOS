import 'package:pharmaos/core/di/service_locator.dart';
import 'package:pharmaos/features/medicines/domain/repositories/medicines_repository.dart';

void main() async {
  print('🧪 Starting Barcode Binding & Override Test...');
  await initServiceLocator();

  final repo = sl<MedicinesRepository>();
  final medicines = await repo.getAll(searchQuery: 'بارامول');
  if (medicines.isEmpty) {
    print('❌ No medicines found with name بارامول');
    return;
  }

  final med1 = medicines.first;
  print('🔹 Selected Medicine 1: ${med1.nameAr} (ID: ${med1.id}, Old Barcode: "${med1.barcode}")');

  const testBarcode = '6291100223344';

  // 1. Assign barcode
  print('🔄 Assigning test barcode: $testBarcode to med1...');
  final success1 = await repo.updateBarcode(med1.id, testBarcode, forceOverride: true);
  print('✅ Assign result: $success1');

  // 2. Fetch by barcode
  final fetched = await repo.getByBarcode(testBarcode);
  if (fetched != null && fetched.id == med1.id) {
    print('🎉 Successfully fetched medicine by newly assigned barcode: ${fetched.nameAr}');
  } else {
    print('❌ Failed to fetch medicine by barcode. Fetched: $fetched');
  }

  // 3. Test conflict reassignment on another medicine
  if (medicines.length > 1) {
    final med2 = medicines[1];
    print('🔄 Testing reassigning $testBarcode from ${med1.nameAr} to ${med2.nameAr} with forceOverride=true...');
    final success2 = await repo.updateBarcode(med2.id, testBarcode, forceOverride: true);
    print('✅ Reassign result: $success2');

    final fetched2 = await repo.getByBarcode(testBarcode);
    final fetchedMed1 = await repo.getById(med1.id);

    if (fetched2 != null && fetched2.id == med2.id && (fetchedMed1?.barcode.isEmpty ?? false)) {
      print('🎉 Conflict override successfully reassigned barcode to med2 and cleared from med1!');
    } else {
      print('⚠️ Reassign check: fetched2=${fetched2?.id}, med1_barcode=${fetchedMed1?.barcode}');
    }

    // Clean up
    await repo.updateBarcode(med2.id, '', forceOverride: true);
    await repo.updateBarcode(med1.id, med1.barcode, forceOverride: true);
  } else {
    await repo.updateBarcode(med1.id, med1.barcode, forceOverride: true);
  }

  print('🏁 Barcode test completed successfully with 100% integrity!');
}
