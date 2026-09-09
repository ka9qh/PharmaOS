# دليل تسمية الملفات والمتغيرات - PharmaOS

- الملفات: snake_case.dart (مثل: medicine_repository.dart)
- الأصناف (Classes): PascalCase (مثل: MedicineRepository)
- المتغيرات والدوال: camelCase (مثل: getMedicineByBarcode)
- الثوابت: camelCase مع static const (مثل: defaultLowStockThreshold)
- كل ميزة (Feature) اسمها بصيغة snake_case مفرد أو جمع واضح (medicines وليس medicine أحيانًا وmedicines أحيانًا أخرى)
- بادئات الجداول في قاعدة البيانات: بدون بادئة، اسم الجدول بصيغة الجمع (medicines, sales, expenses)
