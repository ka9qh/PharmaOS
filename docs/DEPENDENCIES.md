# الاعتماديات (Dependencies) - PharmaOS

انظر pubspec.yaml للقائمة الكاملة والإصدارات الدقيقة. أهم الحزم ودورها:

- drift (>=2.32.0) + sqlite3 (>=3.0.0): قاعدة البيانات المحلية.
  التشفير عبر SQLite3MultipleCiphers (مُفعَّل عبر قسم `hooks.user_defines.sqlite3.source: sqlite3mc`
  في pubspec.yaml) - هذه الطريقة الحديثة الرسمية حلّت محل `sqlcipher_flutter_libs`
  (أصبحت مهجورة رسميًا ولا تفعل شيئًا بداية من إصدارها 0.7.0). لا تُستخدم `sqlcipher_flutter_libs`
  أو `sqlite3_flutter_libs` في هذا المشروع.
- flutter_riverpod + riverpod_annotation: إدارة الحالة.
- go_router: التنقل بين الشاشات.
- get_it: حقن الاعتماديات.
- bcrypt + crypto: تشفير كلمات المرور ومفاتيح الترخيص.
- barcode + qr_flutter: توليد الباركود.
- pdf + printing + excel: تصدير تقارير إغلاق اليومية.

قاعدة: لا تُضاف أي حزمة جديدة تتطلب اتصال إنترنت (مثل حزم API خارجية) دون مبرر قوي وموافقة صريحة.
