import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

final categoryTranslations = {
  'antibacterial': 'مضادات حيوية / بكتيرية',
  'antiprotozoal': 'مضادات الأوالي / طفيليات',
  'antiseptic': 'مطهرات ومعقمات',
  'antiseptic and desinfectants': 'مطهرات ومعقمات',
  'antimalarial': 'أدوية الملاريا',
  'antidiabetics': 'أدوية السكري',
  'analgesic': 'مسكنات ألم',
  'antipyretic': 'خافض حرارة',
  'antibiotic': 'مضادات حيوية',
  'antihistamine': 'مضادات الهيستامين (حساسية)',
  'antacid': 'مضادات الحموضة',
  'antidiarrheal': 'أدوية الإسهال',
  'laxative': 'ملينات',
  'antiemetic': 'أدوية الغثيان والقيء',
  'antifungal': 'مضادات الفطريات',
  'antiviral': 'مضادات الفيروسات',
  'corticosteroid': 'كورتيزون',
  'bronchodilator': 'موسعات الشعب الهوائية',
  'antihypertensive': 'أدوية ضغط الدم',
  'diuretic': 'مدرات البول',
  'anticoagulant': 'مسيلات الدم',
  'lipid-lowering': 'خافضات الكوليسترول',
  'antidepressant': 'مضادات الاكتئاب',
  'anticonvulsant': 'أدوية الصرع والتشنج',
  'vitamin': 'فيتامينات ومكملات غذائية',
  'supplement': 'مكملات غذائية',
  'ophthalmic': 'أدوية العيون',
  'otic': 'أدوية الأذن',
  'nasal': 'أدوية الأنف',
  'topical': 'أدوية موضعية',
  'cardiovascular': 'أدوية القلب والأوعية الدموية',
  'gastrointestinal': 'أدوية الجهاز الهضمي',
  'respiratory': 'أدوية الجهاز التنفسي',
  'dermatological': 'أدوية جلدية',
  'neurological': 'أدوية الجهاز العصبي',
  'psychiatric': 'أدوية نفسية',
  'gynecological': 'أدوية نسائية',
  'urological': 'أدوية المسالك البولية',
  'endocrine': 'أدوية الغدد الصماء والهرمونات',
  'oncology': 'أدوية الأورام',
  'immunology': 'أدوية المناعة',
  'vaccine': 'لقاحات وأمصال',
  'first aid': 'إسعافات أولية',
  'baby care': 'عناية بالطفل',
  'oral care': 'عناية بالفم والأسنان',
  'hair care': 'عناية بالشعر',
  'skin care': 'عناية بالبشرة',
  'personal care': 'عناية شخصية',
  'medical supplies': 'مستلزمات طبية',
  'cosmetics': 'مستحضرات تجميل',
  'antimalarial medicines': 'أدوية الملاريا',
  'antiprtozoal': 'مضادات الأوالي / طفيليات',
};

final companyTranslations = {
  'mup': 'شركة آمون (MUP)',
  'apex pharma': 'أبيكس فارما (Apex Pharma)',
  'thornton&ross ltd(uk)': 'ثورنتون أند روس (Thornton & Ross)',
  'a.b.c international': 'إيه بي سي (A.B.C)',
  'a.p.m': 'إيه بي إم (A.P.M)',
  'gsk': 'جلاكسو سميث كلاين (GSK)',
  'pfizer': 'فايزر (Pfizer)',
  'novartis': 'نوفارتس (Novartis)',
  'sanofi': 'سانوفي (Sanofi)',
  'roche': 'روش (Roche)',
  'merck': 'ميرك (Merck)',
  'bayer': 'باير (Bayer)',
  'astrazeneca': 'أسترازينيكا (AstraZeneca)',
  'johnson & johnson': 'جونسون آند جونسون',
  'abbott': 'أبوت (Abbott)',
};

void main() {
  final dbPath = Platform.environment['APPDATA']! + '\\com.example\\pharmaos\\pharmaos_secure.db';
  final db = sqlite3.open(dbPath);
  db.execute("PRAGMA key = 'PharmaOS-Seed-2026-CHANGE-ME';");

  print('Fixing Categories...');
  final cats = db.select('SELECT id, name FROM categories');
  int catUpdated = 0;
  for (var r in cats) {
    String name = r['name'] as String;
    // Extract english part if exists (in parentheses)
    final match = RegExp(r'\((.*?)\)').firstMatch(name);
    String englishPart = match != null ? match.group(1)!.trim().toLowerCase() : name.trim().toLowerCase();
    
    // Check if we have a translation
    String? translation = categoryTranslations[englishPart];
    
    // Sometimes the name is entirely English without parentheses
    if (translation == null && categoryTranslations.containsKey(name.toLowerCase())) {
        translation = categoryTranslations[name.toLowerCase()];
    }

    if (translation != null) {
      final newName = '${translation} (${englishPart})';
      try {
          db.execute('UPDATE categories SET name = ? WHERE id = ?', [newName, r['id']]);
          print('Updated category: ${name} -> ${newName}');
          catUpdated++;
      } catch (e) {
          print('Skipping due to error (might be duplicate): ${newName}');
      }
    } else {
        // Just title case the english part if we don't have a translation
        final titleCased = englishPart.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join(' ');
        final fallback = '${titleCased}';
        // db.execute('UPDATE categories SET name = ? WHERE id = ?', [fallback, r['id']]);
    }
  }

  print('Fixing Companies...');
  final comps = db.select('SELECT id, name FROM companies');
  int compUpdated = 0;
  for (var r in comps) {
    String name = r['name'] as String;
    // Clean up weird characters like (cid:9)
    String cleanName = name.replaceAll(RegExp(r'\(cid:\d+\)'), '').trim();
    String lowerName = cleanName.toLowerCase();
    
    // Find translation
    String? translation;
    for (var key in companyTranslations.keys) {
      if (lowerName.contains(key)) {
        translation = companyTranslations[key];
        break;
      }
    }

    try {
        if (translation != null) {
          db.execute('UPDATE companies SET name = ? WHERE id = ?', [translation, r['id']]);
          print('Updated company: ${name} -> ${translation}');
          compUpdated++;
        } else if (cleanName != name) {
          // Just update to clean name if it had weird chars
          db.execute('UPDATE companies SET name = ? WHERE id = ?', [cleanName, r['id']]);
          print('Cleaned company: ${name} -> ${cleanName}');
          compUpdated++;
        }
    } catch (e) {
         print('Skipping company due to error: ${name}');
    }
  }

  print('Done! Categories updated: ${catUpdated} | Companies updated: ${compUpdated}');
  db.dispose();
}
