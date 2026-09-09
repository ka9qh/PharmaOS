// أداة تحويل أسماء جميع الأدوية في الكتالوج إلى العربية
// يقرأ الـ CSV الأصلي ويضيف عمود الاسم العربي ويحفظ ملفاً جديداً
//
// الاستخدام: dart run tools/generate_arabic_names.dart

import 'dart:io';
import 'dart:convert';

// ============ قاموس الأسماء التجارية الشائعة ============
const Map<String, String> _knownBrands = {
  // مسكنات وخافضات حرارة
  'panadol': 'بنادول', 'paracetamol': 'باراسيتامول', 'acetaminophen': 'أسيتامينوفين',
  'aspirin': 'أسبرين', 'ibuprofen': 'إيبوبروفين', 'brufen': 'بروفين',
  'voltaren': 'فولتارين', 'diclofenac': 'ديكلوفيناك', 'ketoprofen': 'كيتوبروفين',
  'naproxen': 'نابروكسين', 'celecoxib': 'سيليكوكسيب', 'piroxicam': 'بيروكسيكام',
  'tramadol': 'ترامادول', 'morphine': 'مورفين', 'codeine': 'كودايين',
  'meloxicam': 'ميلوكسيكام', 'etoricoxib': 'إيتوريكوكسيب',
  'indomethacin': 'إندوميثاسين', 'mefenamic': 'ميفيناميك',
  'ketorolac': 'كيتورولاك', 'flurbiprofen': 'فلوربيبروفين',
  'acetylsalicylic': 'أسيتيل ساليسيليك', 'nefopam': 'نيفوبام',
  'pethidine': 'بيثيدين', 'fentanyl': 'فنتانيل', 'nalbuphine': 'نالبوفين',
  'panadeine': 'باناداين', 'solpadeine': 'سولبادين',
  // مضادات حيوية
  'amoxicillin': 'أموكسيسيللين', 'augmentin': 'أوجمنتين', 'amoxil': 'أموكسيل',
  'azithromycin': 'أزيثروميسين', 'zithromax': 'زيثروماكس',
  'ciprofloxacin': 'سيبروفلوكساسين', 'cipro': 'سيبرو', 'ciprobay': 'سيبروباي',
  'cephalexin': 'سيفالكسين', 'cefixime': 'سيفيكسيم', 'ceftriaxone': 'سيفترياكسون',
  'metronidazole': 'ميترونيدازول', 'flagyl': 'فلاجيل',
  'doxycycline': 'دوكسيسيكلين', 'tetracycline': 'تيتراسيكلين',
  'erythromycin': 'إريثروميسين', 'clarithromycin': 'كلاريثروميسين',
  'levofloxacin': 'ليفوفلوكساسين', 'moxifloxacin': 'موكسيفلوكساسين',
  'clindamycin': 'كليندامايسين', 'vancomycin': 'فانكومايسين',
  'gentamicin': 'جنتامايسين', 'tobramycin': 'توبرامايسين',
  'penicillin': 'بنسيلين', 'ampicillin': 'أمبيسيللين',
  'cefuroxime': 'سيفوروكسيم', 'cefotaxime': 'سيفوتاكسيم',
  'cefepime': 'سيفيبيم', 'cefpodoxime': 'سيفبودوكسيم',
  'nitrofurantoin': 'نيتروفورانتوين', 'trimethoprim': 'تريميثوبريم',
  'sulfamethoxazole': 'سلفاميثوكسازول', 'linezolid': 'لينزوليد',
  'ofloxacin': 'أوفلوكساسين', 'norfloxacin': 'نورفلوكساسين',
  'cefaclor': 'سيفاكلور', 'cefadroxil': 'سيفادروكسيل',
  'ceftazidime': 'سيفتازيديم', 'cefoperazone': 'سيفوبيرازون',
  'piperacillin': 'بيبيراسيللين', 'tazobactam': 'تازوباكتام',
  'meropenem': 'ميروبينيم', 'imipenem': 'إيميبينيم',
  'neomycin': 'نيومايسين', 'amikacin': 'أميكاسين',
  'streptomycin': 'ستريبتومايسين', 'kanamycin': 'كانامايسين',
  'rifampicin': 'ريفامبيسين', 'rifampin': 'ريفامبين',
  'isoniazid': 'إيزونيازيد', 'pyrazinamide': 'بيرازيناميد',
  'ethambutol': 'إيثامبيوتول', 'chloramphenicol': 'كلورامفينيكول',
  'fusidic': 'فيوسيديك', 'mupirocin': 'ميوبيروسين',
  'colistin': 'كوليستين', 'polymyxin': 'بوليميكسين',
  'bacitracin': 'باسيتراسين', 'fosfomycin': 'فوسفومايسين',
  // أدوية الضغط والقلب
  'amlodipine': 'أملوديبين', 'atenolol': 'أتينولول', 'bisoprolol': 'بيسوبرولول',
  'captopril': 'كابتوبريل', 'enalapril': 'إنالابريل', 'lisinopril': 'ليسينوبريل',
  'losartan': 'لوسارتان', 'valsartan': 'فالسارتان', 'telmisartan': 'تيلميسارتان',
  'nifedipine': 'نيفيديبين', 'diltiazem': 'ديلتيازيم', 'verapamil': 'فيراباميل',
  'propranolol': 'بروبرانولول', 'carvedilol': 'كارفيديلول',
  'hydrochlorothiazide': 'هيدروكلوروثيازيد', 'furosemide': 'فوروسيميد',
  'spironolactone': 'سبيرونولاكتون', 'indapamide': 'إنداباميد',
  'digoxin': 'ديجوكسين', 'warfarin': 'وارفارين', 'clopidogrel': 'كلوبيدوجريل',
  'rivaroxaban': 'ريفاروكسابان', 'apixaban': 'أبيكسابان',
  'ramipril': 'راميبريل', 'perindopril': 'بيريندوبريل',
  'candesartan': 'كانديسارتان', 'irbesartan': 'إربيسارتان',
  'olmesartan': 'أولميسارتان', 'nebivolol': 'نيبيفولول',
  'metoprolol': 'ميتوبرولول', 'labetalol': 'لابيتالول',
  'prazosin': 'برازوسين', 'doxazosin': 'دوكسازوسين',
  'clonidine': 'كلونيدين', 'minoxidil': 'مينوكسيديل',
  'nimodipine': 'نيموديبين', 'felodipine': 'فيلوديبين',
  'lercanidipine': 'ليركانيديبين',
  // أدوية السكري
  'metformin': 'ميتفورمين', 'glimepiride': 'جليمبيريد', 'glibenclamide': 'جليبينكلاميد',
  'insulin': 'إنسولين', 'sitagliptin': 'سيتاجلبتين', 'januvia': 'جانوفيا',
  'empagliflozin': 'إمباجليفلوزين', 'dapagliflozin': 'داباجليفلوزين',
  'pioglitazone': 'بيوجليتازون', 'gliclazide': 'جليكلازيد',
  'vildagliptin': 'فيلداجلبتين', 'saxagliptin': 'ساكساجلبتين',
  'linagliptin': 'ليناجلبتين', 'canagliflozin': 'كاناجليفلوزين',
  'glipizide': 'جليبيزيد', 'acarbose': 'أكاربوز',
  'repaglinide': 'ريباجلينيد', 'nateglinide': 'ناتيجلينيد',
  'liraglutide': 'ليراجلوتايد', 'exenatide': 'إكسيناتايد',
  'glucophage': 'جلوكوفاج', 'amaryl': 'أماريل', 'diamicron': 'دياميكرون',
  'galvus': 'جالفوس', 'jardiance': 'جارديانس',
  // أدوية المعدة
  'omeprazole': 'أوميبرازول', 'esomeprazole': 'إيسوميبرازول',
  'lansoprazole': 'لانسوبرازول', 'pantoprazole': 'بانتوبرازول',
  'rabeprazole': 'رابيبرازول', 'ranitidine': 'رانيتيدين',
  'famotidine': 'فاموتيدين', 'domperidone': 'دومبيريدون',
  'metoclopramide': 'ميتوكلوبراميد', 'antacid': 'مضاد حموضة',
  'gaviscon': 'جافيسكون', 'nexium': 'نيكسيوم',
  'sucralfate': 'سوكرالفيت', 'misoprostol': 'ميسوبروستول',
  'bismuth': 'بزموث', 'lactulose': 'لاكتولوز',
  'loperamide': 'لوبيراميد', 'imodium': 'إيموديوم',
  'bisacodyl': 'بيساكوديل', 'senna': 'سنا',
  'mebeverine': 'ميبيفيرين', 'hyoscine': 'هيوسين',
  'drotaverine': 'دروتافيرين', 'alverin': 'ألفيرين',
  'ondansetron': 'أوندانسيترون', 'granisetron': 'جرانيسيترون',
  // أدوية الحساسية والتنفس
  'cetirizine': 'سيتريزين', 'loratadine': 'لوراتادين', 'fexofenadine': 'فيكسوفينادين',
  'chlorpheniramine': 'كلورفينيرامين', 'diphenhydramine': 'ديفينهيدرامين',
  'salbutamol': 'سالبيوتامول', 'ventolin': 'فنتولين',
  'budesonide': 'بوديسونيد', 'fluticasone': 'فلوتيكازون',
  'montelukast': 'مونتيلوكاست', 'singulair': 'سنجولير',
  'theophylline': 'ثيوفيلين', 'aminophylline': 'أمينوفيلين',
  'pseudoephedrine': 'سودوإيفيدرين', 'dextromethorphan': 'ديكستروميثورفان',
  'guaifenesin': 'جوايفينيسين', 'bromhexine': 'برومهيكسين',
  'ambroxol': 'أمبروكسول', 'acetylcysteine': 'أسيتيل سيستين',
  'beclomethasone': 'بيكلوميثازون', 'ipratropium': 'إبراتروبيوم',
  'tiotropium': 'تيوتروبيوم', 'formoterol': 'فورموتيرول',
  'salmeterol': 'سالميتيرول', 'terbutaline': 'تيربيوتالين',
  'cromoglycate': 'كروموجليكات', 'ketotifen': 'كيتوتيفين',
  'desloratadine': 'ديسلوراتادين', 'levocetirizine': 'ليفوسيتريزين',
  'bilastine': 'بيلاستين', 'rupatadine': 'روباتادين',
  'triprolidine': 'تريبروليدين', 'promethazine': 'بروميثازين',
  'hydroxyzine': 'هيدروكسيزين', 'cyproheptadine': 'سيبروهيبتادين',
  // فيتامينات ومعادن
  'vitamin': 'فيتامين', 'calcium': 'كالسيوم', 'iron': 'حديد',
  'zinc': 'زنك', 'magnesium': 'ماغنيسيوم', 'folic': 'فوليك',
  'omega': 'أوميغا', 'multivitamin': 'ملتي فيتامين',
  'thiamine': 'ثيامين', 'riboflavin': 'ريبوفلافين',
  'niacin': 'نياسين', 'pyridoxine': 'بيريدوكسين',
  'cyanocobalamin': 'سيانوكوبالامين', 'ascorbic': 'أسكوربيك',
  'tocopherol': 'توكوفيرول', 'retinol': 'ريتينول',
  'cholecalciferol': 'كوليكالسيفيرول', 'ergocalciferol': 'إرجوكالسيفيرول',
  'potassium': 'بوتاسيوم', 'phosphorus': 'فوسفور',
  'selenium': 'سيلينيوم', 'chromium': 'كروميوم',
  'manganese': 'منجنيز', 'copper': 'نحاس',
  'biotin': 'بيوتين', 'pantothenic': 'بانتوثينيك',
  // مضادات الفطريات
  'fluconazole': 'فلوكونازول', 'itraconazole': 'إتراكونازول',
  'ketoconazole': 'كيتوكونازول', 'clotrimazole': 'كلوتريمازول',
  'miconazole': 'ميكونازول', 'nystatin': 'نيستاتين',
  'terbinafine': 'تيربينافين', 'voriconazole': 'فوريكونازول',
  'amphotericin': 'أمفوتيريسين', 'caspofungin': 'كاسبوفنجين',
  'griseofulvin': 'جريزيوفولفين', 'econazole': 'إيكونازول',
  // أدوية الاكتئاب والأعصاب
  'sertraline': 'سيرترالين', 'fluoxetine': 'فلوكسيتين',
  'escitalopram': 'إسيتالوبرام', 'paroxetine': 'باروكسيتين',
  'amitriptyline': 'أميتريبتيلين', 'carbamazepine': 'كاربامازيبين',
  'gabapentin': 'جابابنتين', 'pregabalin': 'بريجابالين',
  'diazepam': 'ديازيبام', 'alprazolam': 'ألبرازولام',
  'clonazepam': 'كلونازيبام', 'phenobarbital': 'فينوباربيتال',
  'phenytoin': 'فينيتوين', 'valproic': 'فالبرويك',
  'levetiracetam': 'ليفيتيراسيتام', 'topiramate': 'توبيراميت',
  'citalopram': 'سيتالوبرام', 'venlafaxine': 'فينلافاكسين',
  'duloxetine': 'دولوكسيتين', 'mirtazapine': 'ميرتازابين',
  'trazodone': 'ترازودون', 'bupropion': 'بوبروبيون',
  'lithium': 'ليثيوم', 'olanzapine': 'أولانزابين',
  'risperidone': 'ريسبيريدون', 'quetiapine': 'كويتيابين',
  'aripiprazole': 'أريبيبرازول', 'haloperidol': 'هالوبيريدول',
  'chlorpromazine': 'كلوربرومازين', 'fluphenazine': 'فلوفينازين',
  'sulpiride': 'سولبيريد', 'amisulpride': 'أميسولبريد',
  'lamotrigine': 'لاموتريجين', 'oxcarbazepine': 'أوكسكاربازيبين',
  'zolpidem': 'زولبيديم', 'zopiclone': 'زوبيكلون',
  'midazolam': 'ميدازولام', 'lorazepam': 'لورازيبام',
  'buspirone': 'بوسبيرون', 'melatonin': 'ميلاتونين',
  // أدوية العيون
  'tobradex': 'توبراديكس', 'timolol': 'تيمولول',
  'latanoprost': 'لاتانوبروست', 'brimonidine': 'بريمونيدين',
  'dorzolamide': 'دورزولاميد', 'travoprost': 'ترافوبروست',
  'pilocarpine': 'بيلوكاربين', 'betaxolol': 'بيتاكسولول',
  'olopatadine': 'أولوباتادين', 'cromoglicate': 'كروموجليكات',
  // الكورتيزونات
  'prednisolone': 'بريدنيزولون', 'prednisone': 'بريدنيزون',
  'dexamethasone': 'ديكساميثازون', 'hydrocortisone': 'هيدروكورتيزون',
  'betamethasone': 'بيتاميثازون', 'triamcinolone': 'تريامسينولون',
  'methylprednisolone': 'ميثيل بريدنيزولون', 'cortisone': 'كورتيزون',
  'mometasone': 'موميتازون', 'clobetasol': 'كلوبيتازول',
  // أدوية الكولسترول
  'atorvastatin': 'أتورفاستاتين', 'rosuvastatin': 'روسوفاستاتين',
  'simvastatin': 'سيمفاستاتين', 'pravastatin': 'برافاستاتين',
  'lipitor': 'ليبيتور', 'crestor': 'كريستور',
  'fenofibrate': 'فينوفايبرات', 'gemfibrozil': 'جمفيبروزيل',
  'ezetimibe': 'إزيتيميب', 'fluvastatin': 'فلوفاستاتين',
  // أدوية الطفيليات والديدان
  'albendazole': 'ألبيندازول', 'mebendazole': 'ميبيندازول',
  'ivermectin': 'إيفرمكتين', 'praziquantel': 'برازيكوانتيل',
  'pyrantel': 'بيرانتيل', 'niclosamide': 'نيكلوساميد',
  'levamisole': 'ليفاميزول', 'diethylcarbamazine': 'ديثيل كاربامازين',
  // أدوية الجلد
  'acne': 'حب الشباب', 'retinoid': 'ريتينويد',
  'isotretinoin': 'آيزوتريتينوين', 'tretinoin': 'تريتينوين',
  'adapalene': 'أدابالين', 'benzoyl': 'بنزويل',
  'calamine': 'كالامين', 'permethrin': 'بيرميثرين',
  'lindane': 'ليندان', 'benzyl': 'بنزيل',
  'salicylic': 'ساليسيليك', 'urea': 'يوريا',
  'calcipotriol': 'كالسيبوتريول', 'tacrolimus': 'تاكروليموس',
  'pimecrolimus': 'بيميكروليموس',
  // أدوية المسالك البولية
  'sildenafil': 'سيلدينافيل', 'tadalafil': 'تادالافيل',
  'tamsulosin': 'تامسولوسين', 'finasteride': 'فيناسترايد',
  'dutasteride': 'دوتاستيرايد', 'alfuzosin': 'ألفوزوسين',
  'terazosin': 'تيرازوسين', 'solifenacin': 'سوليفيناسين',
  'oxybutynin': 'أوكسيبيوتينين', 'tolterodine': 'تولتيرودين',
  // أدوية الغدة الدرقية
  'levothyroxine': 'ليفوثيروكسين', 'propylthiouracil': 'بروبيل ثيوراسيل',
  'carbimazole': 'كاربيمازول', 'methimazole': 'ميثيمازول',
  // أدوية النقرس
  'allopurinol': 'ألوبيورينول', 'colchicine': 'كولشيسين',
  'febuxostat': 'فيبوكسوستات', 'probenecid': 'بروبينسيد',
  // مضادات الملاريا
  'hydroxychloroquine': 'هيدروكسي كلوروكين', 'chloroquine': 'كلوروكين',
  'quinine': 'كينين', 'artemisinin': 'أرتيميسينين',
  'mefloquine': 'ميفلوكين', 'primaquine': 'بريماكين',
  // مضادات الفيروسات
  'acyclovir': 'أسيكلوفير', 'valacyclovir': 'فالاسيكلوفير',
  'oseltamivir': 'أوسيلتاميفير', 'ganciclovir': 'جانسيكلوفير',
  'tenofovir': 'تينوفوفير', 'entecavir': 'إنتيكافير',
  'ribavirin': 'ريبافيرين', 'sofosbuvir': 'سوفوسبوفير',
  'daclatasvir': 'داكلاتاسفير', 'ledipasvir': 'ليديباسفير',
  'zidovudine': 'زيدوفودين', 'lamivudine': 'لاميفودين',
  'efavirenz': 'إيفافيرينز', 'lopinavir': 'لوبينافير',
  'ritonavir': 'ريتونافير', 'atazanavir': 'أتازانافير',
  'abacavir': 'أباكافير', 'emtricitabine': 'إمتريسيتابين',
  // تخدير موضعي
  'lidocaine': 'ليدوكايين', 'bupivacaine': 'بوبيفاكايين',
  'prilocaine': 'بريلوكايين', 'mepivacaine': 'ميبيفاكايين',
  'benzocaine': 'بنزوكايين', 'procaine': 'بروكايين',
  // مضادات التجلط
  'heparin': 'هيبارين', 'enoxaparin': 'إينوكسابارين',
  'tranexamic': 'ترانيكساميك', 'dabigatran': 'دابيجاتران',
  'edoxaban': 'إيدوكسابان', 'fondaparinux': 'فوندابارينوكس',
  // أدوية الحديد
  'ferrous': 'فيروس', 'ferric': 'فيريك',
  // أدوية أخرى شائعة
  'dopamine': 'دوبامين', 'dobutamine': 'دوبيوتامين',
  'adrenaline': 'أدرينالين', 'epinephrine': 'إبينفرين',
  'atropine': 'أتروبين', 'noradrenaline': 'نورأدرينالين',
  'methyldopa': 'ميثيل دوبا', 'hydralazine': 'هيدرالازين',
  'nitroglycerin': 'نيتروجليسرين', 'isosorbide': 'آيزوسوربيد',
  'amiodarone': 'أميودارون', 'adenosine': 'أدينوسين',
  'propafenone': 'بروبافينون', 'flecainide': 'فليكاينيد',
  'ivabradine': 'إيفابرادين', 'ranolazine': 'رانولازين',
  'nitroprusside': 'نيتروبروسايد', 'phenylephrine': 'فينيلفرين',
  'ergometrine': 'إرجوميترين', 'oxytocin': 'أوكسيتوسين',
  'desmopressin': 'ديسموبريسين', 'vasopressin': 'فاسوبريسين',
  'octreotide': 'أوكتريوتايد', 'somatostatin': 'سوماتوستاتين',
  'calcitonin': 'كالسيتونين', 'teriparatide': 'تيريباراتايد',
  'alendronate': 'أليندرونات', 'risedronate': 'ريزيدرونات',
  'zoledronic': 'زوليدرونيك', 'ibandronate': 'إيباندرونات',
  'methotrexate': 'ميثوتريكسات', 'azathioprine': 'أزاثيوبرين',
  'mycophenolate': 'ميكوفينولات', 'ciclosporin': 'سيكلوسبورين',
  'cyclosporine': 'سيكلوسبورين',
  'leflunomide': 'ليفلونوميد', 'sulfasalazine': 'سلفاسالازين',
  'mesalazine': 'ميسالازين', 'olsalazine': 'أولسالازين',
  'balsalazide': 'بالسالازيد',
  'tamoxifen': 'تاموكسيفين', 'letrozole': 'ليتروزول',
  'anastrozole': 'أناستروزول', 'exemestane': 'إكسيميستان',
  'cyclophosphamide': 'سيكلوفوسفاميد', 'cisplatin': 'سيسبلاتين',
  'carboplatin': 'كاربوبلاتين', 'paclitaxel': 'باكليتاكسيل',
  'docetaxel': 'دوسيتاكسيل', 'vincristine': 'فينكريستين',
  'fluorouracil': 'فلورويوراسيل', 'capecitabine': 'كابيسيتابين',
  'gemcitabine': 'جيمسيتابين', 'irinotecan': 'إيرينوتيكان',
  'doxorubicin': 'دوكسوروبيسين', 'epirubicin': 'إبيروبيسين',
  'trastuzumab': 'تراستوزوماب', 'rituximab': 'ريتوكسيماب',
  'imatinib': 'إيماتينيب', 'erlotinib': 'إرلوتينيب',
  'sorafenib': 'سورافينيب', 'sunitinib': 'سونيتينيب',
  'bevacizumab': 'بيفاسيزوماب', 'cetuximab': 'سيتوكسيماب',
  // مستلزمات طبية
  'glucose': 'جلوكوز', 'dextrose': 'ديكستروز',
  'saline': 'محلول ملحي', 'ringer': 'رينجر',
  'mannitol': 'مانيتول', 'albumin': 'ألبومين',
};

/// خريطة المقاطع الصوتية
const Map<String, String> _syllables = {
  'ph': 'ف', 'th': 'ث', 'ch': 'تش', 'sh': 'ش',
  'tion': 'شن', 'sion': 'شن', 'ine': 'ين', 'ene': 'ين',
  'ol': 'ول', 'al': 'ال', 'il': 'يل', 'el': 'يل',
  'an': 'ان', 'en': 'ين', 'in': 'ين', 'on': 'ون', 'un': 'ون',
  'am': 'ام', 'em': 'يم', 'im': 'يم', 'om': 'وم', 'um': 'وم',
  'ar': 'ار', 'er': 'ير', 'ir': 'ير', 'or': 'ور', 'ur': 'ور',
  'ate': 'ات', 'ide': 'ايد', 'ose': 'وز', 'ase': 'از',
  'yl': 'يل', 'ic': 'يك', 'oc': 'وك',
  'oo': 'و', 'ee': 'ي', 'ea': 'يا', 'ou': 'او',
  'ck': 'ك', 'ss': 'س', 'tt': 'ت', 'll': 'ل',
  'mm': 'م', 'nn': 'ن', 'pp': 'ب', 'rr': 'ر',
  'ff': 'ف', 'dd': 'د', 'bb': 'ب', 'gg': 'ج',
  'zz': 'ز', 'cc': 'ك',
};

const Map<String, String> _charMap = {
  'a': 'ا', 'b': 'ب', 'c': 'ك', 'd': 'د', 'e': 'ي',
  'f': 'ف', 'g': 'ج', 'h': 'ه', 'i': 'ي', 'j': 'ج',
  'k': 'ك', 'l': 'ل', 'm': 'م', 'n': 'ن', 'o': 'و',
  'p': 'ب', 'q': 'ك', 'r': 'ر', 's': 'س', 't': 'ت',
  'u': 'و', 'v': 'ف', 'w': 'و', 'x': 'كس', 'y': 'ي',
  'z': 'ز',
};

String transliterateWord(String word) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < word.length) {
    bool matched = false;
    // Try 4, 3, 2 char syllables
    for (final len in [4, 3, 2]) {
      if (i + len <= word.length) {
        final sub = word.substring(i, i + len);
        if (_syllables.containsKey(sub)) {
          buffer.write(_syllables[sub]);
          i += len;
          matched = true;
          break;
        }
      }
    }
    if (!matched) {
      buffer.write(_charMap[word[i]] ?? word[i]);
      i++;
    }
  }
  return buffer.toString();
}

String transliterate(String name) {
  if (name.trim().isEmpty) return '';
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(name)) return name;

  final words = name.split(RegExp(r'[\s+\-/]+'));
  final arabic = <String>[];
  
  for (final word in words) {
    final clean = word.replaceAll(RegExp(r'[^a-zA-Z0-9.%]'), '').toLowerCase();
    if (clean.isEmpty) continue;
    if (RegExp(r'^[0-9.%]+$').hasMatch(clean)) { arabic.add(word); continue; }
    
    final known = _knownBrands[clean];
    if (known != null) { arabic.add(known); continue; }
    
    arabic.add(transliterateWord(clean));
  }
  
  return arabic.isEmpty ? name : arabic.join(' ');
}

void main() {
  final inputFile = File('seed_data/yemen_pharmacy_guide_medicines.csv');
  final outputFile = File('assets/data/medicines_catalog.csv');
  
  // قراءة الملف الأصلي
  final bytes = inputFile.readAsBytesSync();
  String content;
  try {
    content = utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    content = latin1.decode(bytes);
  }
  content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  
  final lines = content.split('\n');
  if (lines.isEmpty) {
    print('ملف فارغ!');
    return;
  }
  
  // كتابة الملف الجديد بصيغة UTF-8 مع عمود الاسم العربي
  final output = StringBuffer();
  // رأس الجدول الجديد
  output.writeln('name_en,name_ar,scientific_name,category,company,form,dosage,country,pack_size');
  
  int processed = 0;
  int skipped = 0;
  
  // تخطي الصف الأول (العناوين القديمة)
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    
    // تحليل CSV يدوياً (بسبب الحقول التي تحتوي فواصل داخل علامات تنصيص)
    final fields = _parseCsvLine(line);
    if (fields.isEmpty || fields[0].trim().isEmpty) {
      skipped++;
      continue;
    }
    
    final tradeName = fields[0].trim();
    final scientificName = fields.length > 1 ? fields[1].trim() : '';
    final category = fields.length > 2 ? fields[2].trim() : '';
    final company = fields.length > 3 ? fields[3].trim() : '';
    final form = fields.length > 4 ? fields[4].trim() : '';
    final dosage = fields.length > 5 ? fields[5].trim() : '';
    final country = fields.length > 6 ? fields[6].trim() : '';
    final packSize = fields.length > 7 ? fields[7].trim() : '';
    
    // توليد الاسم العربي
    final nameAr = transliterate(tradeName);
    
    // كتابة الصف الجديد
    output.writeln('${_csvEscape(tradeName)},${_csvEscape(nameAr)},${_csvEscape(scientificName)},${_csvEscape(category)},${_csvEscape(company)},${_csvEscape(form)},${_csvEscape(dosage)},${_csvEscape(country)},${_csvEscape(packSize)}');
    processed++;
  }
  
  outputFile.writeAsStringSync(output.toString(), encoding: utf8);
  
  print('');
  print('=== تم توليد الأسماء العربية بنجاح ===');
  print('عدد الأدوية المعالجة: $processed');
  print('عدد الأسطر المتخطاة: $skipped');
  print('الملف الناتج: ${outputFile.path}');
  print('');
  
  // عرض أمثلة
  print('=== أمثلة على الأسماء المولّدة ===');
  final sampleLines = outputFile.readAsLinesSync().skip(1).take(20);
  for (final l in sampleLines) {
    final parts = _parseCsvLine(l);
    if (parts.length >= 2) {
      print('  ${parts[0].padRight(35)} → ${parts[1]}');
    }
  }
}

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  var current = StringBuffer();
  var inQuotes = false;
  
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current.write(ch);
      }
    } else {
      if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(ch);
      }
    }
  }
  result.add(current.toString());
  return result;
}
