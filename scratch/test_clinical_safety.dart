import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaos/core/services/medicine_clinical_helper.dart';

void main() {
  test('Clinical Safety and Alternatives Engine Verification', () {
    final testMeds = [
      {'name': 'فولتارين 50 ملجم', 'sci': 'Diclofenac Sodium', 'cat': 'Analgesic'},
      {'name': 'بروفين 400 ملجم', 'sci': 'Ibuprofen', 'cat': 'Analgesic'},
      {'name': 'بانادول ازرق', 'sci': 'Paracetamol 500mg', 'cat': 'Analgesic'},
      {'name': 'كونجستال اقراص', 'sci': 'Paracetamol + Pseudoephedrine + Chlorpheniramine', 'cat': 'Cold & Flu'},
      {'name': 'اوجمنتين 1 جم', 'sci': 'Amoxicillin + Clavulanic acid', 'cat': 'Antibiotic'},
      {'name': 'سيبروفلوكساسين 500', 'sci': 'Ciprofloxacin', 'cat': 'Antibiotic'},
      {'name': 'سايتوتيك 200', 'sci': 'Misoprostol', 'cat': 'GI'},
      {'name': 'ليبيتور 20 ملجم', 'sci': 'Atorvastatin', 'cat': 'Cardio / Lipid'},
      {'name': 'وارفارين 5 ملجم', 'sci': 'Warfarin', 'cat': 'Anticoagulant'},
      {'name': 'كونكور 5 ملجم', 'sci': 'Bisoprolol', 'cat': 'Cardio / Beta blocker'},
    ];

    for (final m in testMeds) {
      final profile = MedicineClinicalHelper.getFullClinicalProfile(
        medicineName: m['name']!,
        scientificName: m['sci'],
        categoryName: m['cat'],
      );

      print('\n💊 الدواء: ${m['name']} (${m['sci']})');
      print('   🤰 حالة الحوامل: ${profile.pregnancy.statusLabel}');
      print('      البديل للحوامل: ${profile.pregnancy.safeAlternative}');
      print('   ❤️ حالة القلب: ${profile.cardiac.statusLabel}');
      print('      البديل لمرضى القلب: ${profile.cardiac.safeAlternative}');
      print('   ⚠️ التحذيرات العامة: ${profile.generalWarnings.warnings.join(" | ")}');
    }

    // Verify key safety rules:
    // 1. Voltaren / Diclofenac should be UNSAFE for pregnancy and warning for heart
    final voltaren = MedicineClinicalHelper.getFullClinicalProfile(medicineName: 'Voltaren', scientificName: 'Diclofenac');
    expect(voltaren.pregnancy.isSafe, isFalse);
    expect(voltaren.cardiac.isSafe, isFalse);
    expect(voltaren.pregnancy.safeAlternative, contains('باراسيتامول'));

    // 2. Panadol / Paracetamol should be SAFE for pregnancy and SAFE for heart
    final panadol = MedicineClinicalHelper.getFullClinicalProfile(medicineName: 'Panadol', scientificName: 'Paracetamol');
    expect(panadol.pregnancy.isSafe, isTrue);
    expect(panadol.cardiac.isSafe, isTrue);

    // 3. Congestal should be UNSAFE for heart and UNSAFE for pregnancy
    final congestal = MedicineClinicalHelper.getFullClinicalProfile(medicineName: 'Congestal', scientificName: 'Pseudoephedrine');
    expect(congestal.pregnancy.isSafe, isFalse);
    expect(congestal.cardiac.isSafe, isFalse);
    expect(congestal.cardiac.safeAlternative, contains('باراسيتامول'));

    // 4. Cytotec should be UNSAFE for pregnancy
    final cytotec = MedicineClinicalHelper.getFullClinicalProfile(medicineName: 'Cytotec', scientificName: 'Misoprostol');
    expect(cytotec.pregnancy.isSafe, isFalse);

    // 5. Lipitor should be UNSAFE for pregnancy
    final lipitor = MedicineClinicalHelper.getFullClinicalProfile(medicineName: 'Lipitor', scientificName: 'Atorvastatin');
    expect(lipitor.pregnancy.isSafe, isFalse);
  });
}
