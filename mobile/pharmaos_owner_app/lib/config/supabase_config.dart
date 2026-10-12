// إعدادات ومفاتيح الربط بالسيرفر السحابي Supabase - PharmaOS Owner App
// نصوص صريحة وثابتة (Hardcoded Constants) لضمان عدم فقدانها في نسخ الـ Release المترجمة

class SupabaseConfig {
  /// رابط مشروع Supabase المعتمد
  static const String url = 'https://bwgilcmzffcwdcxhfyfk.supabase.co';

  /// مفتاح الوصول العام المعتمد (Anon / Publishable Key)
  static const String anonKey = 'sb_publishable_fS45ChjUqSx9LV3IBjny_A_kv048V16';

  /// مهلة الاتصال الافتراضية المناسبة للإنترنت الضعيف وبطيء الاستجابة
  static const Duration requestTimeout = Duration(seconds: 35);

  /// مهلة الاتصال بالسوكت/المصافحة الأولية
  static const Duration connectionTimeout = Duration(seconds: 30);
}
