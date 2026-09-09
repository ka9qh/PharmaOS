import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final dbPath = '$appData\\com.example\\pharmaos\\pharmaos_secure.db';
  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    print('Database not found at $dbPath');
    return;
  }

  print('Updating Categories and Companies tables to show Arabic and English names...');
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  // A simple dictionary for common categories since ArabicTransliterator might transliterate them literally (e.g. "انتيبيوتيك" instead of "مضاد حيوي")
  final categoryTranslations = {
    'antibiotic': 'مضاد حيوي',
    'analgesic': 'مسكن ألم',
    'antipyretic': 'خافض حرارة',
    'nsaid': 'مضاد التهاب',
    'vitamin': 'فيتامين',
    'supplement': 'مكمل غذائي',
    'antacid': 'مضاد حموضة',
    'antihistamine': 'مضاد حساسية',
    'corticosteroid': 'كورتيزون',
    'antifungal': 'مضاد فطريات',
    'antiviral': 'مضاد فيروسات',
    'antidiabetic': 'أدوية السكري',
    'antihypertensive': 'أدوية الضغط',
    'diuretic': 'مدر بول',
    'laxative': 'ملين',
    'antiemetic': 'مضاد قيء',
    'antispasmodic': 'مضاد تشنج',
    'bronchodilator': 'موسع قصبات',
    'expectorant': 'طارد بلغم',
    'antitussive': 'مهدئ سعال',
    'sedative': 'مهدئ',
    'antidepressant': 'مضاد اكتئاب',
    'anticonvulsant': 'مضاد اختلاج',
    'vaccine': 'لقاح',
    'eye drops': 'قطرات عين',
    'ear drops': 'قطرات أذن',
    'nasal spray': 'بخاخ أنف',
    'ointment': 'مرهم',
    'cream': 'كريم',
    'gel': 'جل',
    'syrup': 'شراب',
    'tablet': 'حبوب',
    'capsule': 'كبسول',
    'injection': 'حقن',
    'suppository': 'تحاميل',
    'inhaler': 'بخاخ',
  };

  // Companies usually can just be transliterated. I will use a simple phonetic replacement for companies.
  String transliterate(String englishName) {
    if (englishName.trim().isEmpty) return '';
    String txt = englishName.trim().toLowerCase();
    
    // Check known categories
    for (final entry in categoryTranslations.entries) {
      if (txt.contains(entry.key)) {
        return entry.value;
      }
    }

    // Basic transliteration for companies
    final Map<String, String> rules = {
      'pharma': 'فارما',
      'medical': 'ميديكال',
      'group': 'جروب',
      'industries': 'للصناعات',
      'co': 'شركة',
      'ltd': 'المحدودة',
      'inc': 'انك',
      'a': 'ا', 'b': 'ب', 'c': 'ك', 'd': 'د', 'e': 'ي', 'f': 'ف', 'g': 'ج',
      'h': 'ه', 'i': 'ي', 'j': 'ج', 'k': 'ك', 'l': 'ل', 'm': 'م', 'n': 'ن',
      'o': 'و', 'p': 'ب', 'q': 'ك', 'r': 'ر', 's': 'س', 't': 'ت', 'u': 'و',
      'v': 'ف', 'w': 'و', 'x': 'كس', 'y': 'ي', 'z': 'ز',
      'sh': 'ش', 'ch': 'تش', 'th': 'ث', 'ph': 'ف', 'kh': 'خ', 'gh': 'غ'
    };

    String result = '';
    // Let's just do a quick word mapping for companies if they are English
    final words = englishName.split(' ');
    for (String w in words) {
      String lw = w.toLowerCase();
      if (rules.containsKey(lw)) {
        result += rules[lw]! + ' ';
      } else {
        // Just keep it as is if we can't map it, or use the first letter mapping
        // Actually since it's just a few companies, we can just do a very basic phonetic
        String mappedWord = '';
        for (int i = 0; i < lw.length; i++) {
          if (i < lw.length - 1 && rules.containsKey(lw.substring(i, i+2))) {
            mappedWord += rules[lw.substring(i, i+2)]!;
            i++;
          } else if (rules.containsKey(lw[i])) {
            mappedWord += rules[lw[i]]!;
          } else {
            mappedWord += lw[i];
          }
        }
        result += mappedWord + ' ';
      }
    }
    
    return result.trim();
  }

  try {
    db.execute('BEGIN TRANSACTION;');

    // Update Categories
    final categories = db.select('SELECT id, name FROM Categories;');
    for (final row in categories) {
      final name = row['name'] as String;
      if (!name.contains('(')) {
        final ar = transliterate(name);
        final newName = '$ar ($name)';
        db.execute('UPDATE Categories SET name = ? WHERE id = ?;', [newName, row['id']]);
      }
    }

    // Update Companies
    final companies = db.select('SELECT id, name FROM Companies;');
    for (final row in companies) {
      final name = row['name'] as String;
      if (!name.contains('(')) {
        final ar = transliterate(name);
        final newName = '$ar ($name)';
        db.execute('UPDATE Companies SET name = ? WHERE id = ?;', [newName, row['id']]);
      }
    }

    db.execute('COMMIT;');
    print('Categories and Companies updated successfully.');
  } catch (e) {
    db.execute('ROLLBACK;');
    print('Error: $e');
  }

  db.dispose();
}
