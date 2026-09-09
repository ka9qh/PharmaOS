# إدارة الحالة - PharmaOS (Riverpod)

- Riverpod هو الحل الوحيد المعتمد لإدارة الحالة عبر كامل النظام.
- **تحديث Phase 1/2**: النمط المعتمد فعليًا هو Notifier اليدوي (`class X extends Notifier<State>`)
  بدون Code Generation، وليس `@riverpod` (riverpod_generator) كما كان في Skeleton الأصلي.
  السبب: تقليل نقاط فشل الترجمة (build_runner) لمطور مبتدئ يدير المشروع بمساعدة الذكاء
  الاصطناعي فقط. ميزات Auth, Categories, Companies, Medicines, Inventory كلها تتبع هذا
  النمط الآن. الميزات التي لم تُبنَ بعد لا تزال تحمل Skeleton بنمط `@riverpod` القديم إلى
  حين الوصول لمرحلتها في خارطة الطريق - عندها ستُحوَّل لنفس نمط Notifier اليدوي للتوحيد.
- كل ميزة لها Provider خاص بها في presentation/providers، بصيغة:
  `class XState {...}` + `class XNotifier extends Notifier<XState> {...}` +
  `final xNotifierProvider = NotifierProvider<XNotifier, XState>(XNotifier.new);`
- الحالة المشتقة (Derived State) مثل "هل السلة فارغة؟" تُحسب عبر getter داخل State نفسه
  (مثال: `StockSummary.isLow`) وليس داخل الشاشة مباشرة.
- لا تُستخدم StatefulWidget إلا لحالة واجهة بسيطة جدًا (مثل TextEditingController محلي).
